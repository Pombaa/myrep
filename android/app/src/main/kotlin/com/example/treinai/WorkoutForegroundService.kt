package com.example.treinai

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.Handler
import android.os.Looper
import android.os.Vibrator
import android.os.VibratorManager
import android.media.RingtoneManager
import android.media.MediaPlayer
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class WorkoutForegroundService : Service() {
    
    private var wakeLock: PowerManager.WakeLock? = null
    private var isServiceStarted = false
    private var restTimer: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())
    private var remainingSeconds = 0
    private var mediaPlayer: MediaPlayer? = null
    
    companion object {
        const val CHANNEL_ID = "workout_foreground_service"
        const val NOTIFICATION_ID = 1
        
        const val ACTION_START = "com.example.treinai.action.START"
        const val ACTION_STOP = "com.example.treinai.action.STOP"
        const val ACTION_COMPLETE_SET = "com.example.treinai.action.COMPLETE_SET"
        const val ACTION_STOP_REST = "com.example.treinai.action.STOP_REST"
        const val ACTION_UPDATE = "com.example.treinai.action.UPDATE"
        const val ACTION_START_REST = "com.example.treinai.action.START_REST"
        const val ACTION_CANCEL_WORKOUT = "com.example.treinai.action.CANCEL_WORKOUT"
        const val ACTION_STOP_REST_SILENT = "com.example.treinai.action.STOP_REST_SILENT"
        
        var methodChannel: MethodChannel? = null
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startService()
            ACTION_STOP -> stopService()
            ACTION_COMPLETE_SET -> handleCompleteSet()
            ACTION_STOP_REST -> handleStopRest()
            ACTION_UPDATE -> updateNotification(intent)
            ACTION_START_REST -> startRestTimer(intent)
            ACTION_CANCEL_WORKOUT -> handleCancelWorkout()
            ACTION_STOP_REST_SILENT -> stopRestSilent()
        }
        
        return START_STICKY
    }
    
    private fun startService() {
        if (isServiceStarted) return
        
        isServiceStarted = true
        
        createNotificationChannel()
        
        // Acquire wake lock
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager).run {
            newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "TreinAI::WorkoutLock").apply {
                acquire(10*60*1000L) // 10 minutes
            }
        }
        
        val notification = buildNotification(
            "Iniciando treino...",
            "Preparando",
            false
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, 
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
    
    private fun stopService() {
        try {
            stopRestTimer()
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            stopForeground(true)
            stopSelf()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        isServiceStarted = false
    }
    
    private fun handleCompleteSet() {
        // Notifica o Flutter
        methodChannel?.invokeMethod("onCompleteSet", null)
    }
    
    private fun handleStopRest() {
        // Para o timer
        stopRestTimer()
        
        // Notifica o Flutter
        methodChannel?.invokeMethod("onStopRest", null)
    }
    
    private fun handleCancelWorkout() {
        // Para o serviço completamente
        stopService()
        
        // Notifica o Flutter que o treino foi cancelado
        methodChannel?.invokeMethod("onWorkoutCancelled", null)
    }
    
    private fun startRestTimer(intent: Intent) {
        val seconds = intent.getIntExtra("seconds", 60)
        val exerciseName = intent.getStringExtra("exerciseName") ?: "Exercício"
        val currentSet = intent.getIntExtra("currentSet", 1)
        val totalSets = intent.getIntExtra("totalSets", 3)
        
        remainingSeconds = seconds
        
        // Para timer anterior se existir
        stopRestTimer()
        
        // Cria novo timer
        restTimer = object : Runnable {
            override fun run() {
                if (remainingSeconds > 0) {
                    // Alerta nos últimos 3 segundos
                    val title = if (remainingSeconds <= 3) {
                        "⏰ ATENÇÃO! ${remainingSeconds}s"
                    } else {
                        "⏱ Descanso - ${remainingSeconds}s"
                    }
                    
                    // Atualiza notificação
                    val notification = buildNotification(
                        title,
                        "Próximo: Série $currentSet/$totalSets - $exerciseName",
                        true
                    )
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(NOTIFICATION_ID, notification)
                    
                    remainingSeconds--
                    handler.postDelayed(this, 1000)
                } else {
                    // Timer completou - TOCA ALARME
                    playAlarmAndVibrate()
                    
                    // Atualiza notificação para indicar que acabou
                    val notification = buildNotification(
                        "✅ Descanso finalizado!",
                        "Série $currentSet/$totalSets - $exerciseName",
                        false
                    )
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(NOTIFICATION_ID, notification)
                    
                    stopRestTimer()
                    methodChannel?.invokeMethod("onRestComplete", null)
                }
            }
        }
        
        handler.post(restTimer!!)
    }
    
    private fun stopRestTimer() {
        restTimer?.let {
            handler.removeCallbacks(it)
            restTimer = null
        }
        stopAlarm()
    }

    /** Stops rest from the Flutter UI without invoking onStopRest (avoids feedback loop). */
    private fun stopRestSilent() {
        stopRestTimer()
        remainingSeconds = 0
        val notification = buildNotification(
            "Treino em andamento",
            "Descanso pulado",
            false
        )
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun playAlarmAndVibrate() {
        try {
            // Para alarme anterior se existir
            stopAlarm()
            
            // Toca som de notificação
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            mediaPlayer = MediaPlayer.create(this, alarmUri)
            mediaPlayer?.isLooping = false
            mediaPlayer?.start()
            
            // Vibra por 2 segundos com padrão
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            // Padrão: espera 0ms, vibra 500ms, espera 200ms, vibra 500ms
            val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    android.os.VibrationEffect.createWaveform(pattern, -1)
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun stopAlarm() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
                mediaPlayer = null
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun updateNotification(intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Treino em andamento"
        val content = intent.getStringExtra("content") ?: ""
        val isResting = intent.getBooleanExtra("isResting", false)
        
        val notification = buildNotification(title, content, isResting)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun buildNotification(title: String, content: String, isResting: Boolean): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)  // TRANSPORT para ficar no topo
            .setPriority(NotificationCompat.PRIORITY_MAX)  // MAX para garantir visibilidade
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)  // Visível na tela de bloqueio
            .setSound(null)  // Remove som
            .setVibrate(null)  // Remove vibração
            .setOnlyAlertOnce(true)  // Alerta apenas na primeira vez
            .setSilent(true)  // Modo silencioso
            .setShowWhen(false)  // Remove timestamp
            .setUsesChronometer(false)  // Não usa cronômetro
            .setColorized(true)  // Destaca com cor
            .setColor(0xFF6200EE.toInt())  // Cor primária (roxo Material)
            .setAutoCancel(false)  // Não cancela ao clicar
            .setLocalOnly(true)  // Apenas local (não sincroniza com wearables)
            .setGroup("workout_session")  // Agrupa notificações de treino
            .setGroupSummary(false)  // Esta não é um resumo de grupo
            .setSortKey("0")  // "0" coloca no topo (ordenação alfabética)
        
        // Adiciona estilo de mídia para fixar no topo
        // setShowActionsInCompactView(0) - mostra APENAS primeira ação na visualização compacta
        // O botão "Cancelar" (índice 1) só aparece quando expandir
        val mediaStyle = androidx.media.app.NotificationCompat.MediaStyle()
            .setShowActionsInCompactView(0)  // Mostra APENAS primeira ação (Concluir/Parar descanso)
        builder.setStyle(mediaStyle)
        
        // Adiciona ações baseadas no estado
        if (isResting) {
            // Durante descanso
            val stopRestIntent = Intent(this, WorkoutForegroundService::class.java).apply {
                action = ACTION_STOP_REST
            }
            val stopRestPendingIntent = PendingIntent.getService(
                this, 1, stopRestIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            builder.addAction(
                android.R.drawable.ic_media_play,  // Ícone de play
                "⏹ Parar descanso",
                stopRestPendingIntent
            )
        } else {
            // Durante exercício
            val completeSetIntent = Intent(this, WorkoutForegroundService::class.java).apply {
                action = ACTION_COMPLETE_SET
            }
            val completeSetPendingIntent = PendingIntent.getService(
                this, 2, completeSetIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            builder.addAction(
                android.R.drawable.ic_media_play,  // Ícone de play
                "✓ Concluir série",
                completeSetPendingIntent
            )
        }
        
        // Botão de CANCELAR TREINO (sempre presente)
        val cancelIntent = Intent(this, WorkoutForegroundService::class.java).apply {
            action = ACTION_CANCEL_WORKOUT
        }
        val cancelPendingIntent = PendingIntent.getService(
            this, 3, cancelIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        builder.addAction(
            android.R.drawable.ic_delete,
            "✕ Cancelar treino",
            cancelPendingIntent
        )
        
        return builder.build()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Sessão de Treino",
                NotificationManager.IMPORTANCE_HIGH  // HIGH para aparecer no topo
            ).apply {
                description = "Controle de treino em andamento (como player de música)"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)  // Remove som do canal
                enableVibration(false)  // Desabilita vibração
                enableLights(false)  // Desabilita luz de LED
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
