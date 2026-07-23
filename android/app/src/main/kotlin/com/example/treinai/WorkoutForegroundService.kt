package com.example.treinai

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class WorkoutForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var isServiceStarted = false
    private var restTimer: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())
    private var restEndsAtElapsed: Long = 0L
    private var restExerciseName: String = "Exercício"
    private var restCurrentSet: Int = 1
    private var restTotalSets: Int = 3
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
            ACTION_START -> startForegroundSession(intent)
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

    private fun startForegroundSession(intent: Intent?) {
        createNotificationChannel()
        acquireWakeLock(10 * 60 * 1000L)

        val title = intent?.getStringExtra("title") ?: "Treino em andamento"
        val content = intent?.getStringExtra("content") ?: "Sessão ativa"
        val isResting = intent?.getBooleanExtra("isResting", false) ?: false

        val notification = buildNotification(title, content, isResting, restEndsAtMs = 0L)
        promoteToForeground(notification)
        isServiceStarted = true
    }

    private fun promoteToForeground(notification: Notification) {
        // mediaPlayback keeps the session sticky in the shade like a music player.
        // (health type would also need ACTIVITY_RECOGNITION on API 34+.)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureForeground() {
        if (isServiceStarted) return
        createNotificationChannel()
        acquireWakeLock(10 * 60 * 1000L)
        val notification = buildNotification(
            "Treino em andamento",
            "Sessão ativa",
            false,
            restEndsAtMs = 0L
        )
        promoteToForeground(notification)
        isServiceStarted = true
    }

    private fun acquireWakeLock(durationMs: Long) {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {
        }
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager).run {
            newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "TreinAI::WorkoutLock").apply {
                acquire(durationMs.coerceAtLeast(60_000L))
            }
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
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        isServiceStarted = false
    }

    private fun handleCompleteSet() {
        methodChannel?.invokeMethod("onCompleteSet", null)
    }

    private fun handleStopRest() {
        stopRestTimer()
        methodChannel?.invokeMethod("onStopRest", null)
    }

    private fun handleCancelWorkout() {
        stopService()
        methodChannel?.invokeMethod("onWorkoutCancelled", null)
    }

    private fun remainingRestSeconds(): Int {
        if (restEndsAtElapsed <= 0L) return 0
        val left = ((restEndsAtElapsed - SystemClock.elapsedRealtime()) / 1000L).toInt()
        return left.coerceAtLeast(0)
    }

    private fun startRestTimer(intent: Intent) {
        ensureForeground()

        val seconds = intent.getIntExtra("seconds", 60).coerceAtLeast(1)
        restExerciseName = intent.getStringExtra("exerciseName") ?: "Exercício"
        restCurrentSet = intent.getIntExtra("currentSet", 1)
        restTotalSets = intent.getIntExtra("totalSets", 3)

        stopRestTimerCallbacksOnly()

        restEndsAtElapsed = SystemClock.elapsedRealtime() + seconds * 1000L
        // Keep CPU awake through the rest (+ buffer for alarm).
        acquireWakeLock((seconds + 15) * 1000L)

        val endsAtWall = System.currentTimeMillis() + seconds * 1000L
        publishRestNotification(endsAtWall, remainingRestSeconds())

        restTimer = object : Runnable {
            override fun run() {
                val remaining = remainingRestSeconds()
                if (remaining > 0) {
                    val endsAtWallTick =
                        System.currentTimeMillis() + remaining * 1000L
                    publishRestNotification(endsAtWallTick, remaining)
                    // Tick slightly under 1s so we don't drift late under load.
                    handler.postDelayed(this, 500)
                } else {
                    playAlarmAndVibrate()
                    val notification = buildNotification(
                        "✅ Descanso finalizado!",
                        "Série $restCurrentSet/$restTotalSets - $restExerciseName",
                        false,
                        restEndsAtMs = 0L
                    )
                    val notificationManager =
                        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(NOTIFICATION_ID, notification)

                    stopRestTimerCallbacksOnly()
                    restEndsAtElapsed = 0L
                    methodChannel?.invokeMethod("onRestComplete", null)
                }
            }
        }
        handler.post(restTimer!!)
    }

    private fun publishRestNotification(endsAtWallMs: Long, remaining: Int) {
        val title = if (remaining <= 3) {
            "⏰ ATENÇÃO! ${remaining}s"
        } else {
            "⏱ Descanso"
        }
        val content = "Próximo: Série $restCurrentSet/$restTotalSets - $restExerciseName"
        val notification = buildNotification(
            title,
            content,
            true,
            restEndsAtMs = endsAtWallMs
        )
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun stopRestTimerCallbacksOnly() {
        restTimer?.let {
            handler.removeCallbacks(it)
            restTimer = null
        }
        stopAlarm()
    }

    private fun stopRestTimer() {
        stopRestTimerCallbacksOnly()
        restEndsAtElapsed = 0L
    }

    /** Stops rest from the Flutter UI without invoking onStopRest (avoids feedback loop). */
    private fun stopRestSilent() {
        stopRestTimer()
        val notification = buildNotification(
            "Treino em andamento",
            "Descanso pulado",
            false,
            restEndsAtMs = 0L
        )
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun playAlarmAndVibrate() {
        try {
            stopAlarm()

            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            mediaPlayer = MediaPlayer.create(this, alarmUri)
            mediaPlayer?.isLooping = false
            mediaPlayer?.start()

            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager =
                    getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

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
        ensureForeground()
        val title = intent.getStringExtra("title") ?: "Treino em andamento"
        val content = intent.getStringExtra("content") ?: ""
        val isResting = intent.getBooleanExtra("isResting", false)

        // Don't clobber an active rest countdown with a stale non-rest update.
        if (!isResting && remainingRestSeconds() > 0) {
            return
        }

        val restEndsAtMs = if (isResting && remainingRestSeconds() > 0) {
            System.currentTimeMillis() + remainingRestSeconds() * 1000L
        } else {
            0L
        }

        val notification = buildNotification(title, content, isResting, restEndsAtMs)
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(
        title: String,
        content: String,
        isResting: Boolean,
        restEndsAtMs: Long
    ): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
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
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(true)
            .setColorized(true)
            .setColor(0xFF6200EE.toInt())
            .setAutoCancel(false)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)

        if (isResting && restEndsAtMs > 0L) {
            builder
                .setWhen(restEndsAtMs)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setSubText("Descanso")
        } else {
            builder
                .setUsesChronometer(false)
                .setShowWhen(false)
        }

        val mediaStyle = androidx.media.app.NotificationCompat.MediaStyle()
            .setShowActionsInCompactView(0)
        builder.setStyle(mediaStyle)

        if (isResting) {
            val stopRestIntent = Intent(this, WorkoutForegroundService::class.java).apply {
                action = ACTION_STOP_REST
            }
            val stopRestPendingIntent = PendingIntent.getService(
                this, 1, stopRestIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            builder.addAction(
                android.R.drawable.ic_media_play,
                "⏹ Parar descanso",
                stopRestPendingIntent
            )
        } else {
            val completeSetIntent = Intent(this, WorkoutForegroundService::class.java).apply {
                action = ACTION_COMPLETE_SET
            }
            val completeSetPendingIntent = PendingIntent.getService(
                this, 2, completeSetIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            builder.addAction(
                android.R.drawable.ic_media_play,
                "✓ Concluir série",
                completeSetPendingIntent
            )
        }

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
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Timer de descanso e controle do treino (tela bloqueada / barra)"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
