package com.example.treinai

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.treinai/workout_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        WorkoutForegroundService.methodChannel = methodChannel

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val title = call.argument<String>("title") ?: "Treino em andamento"
                    val content = call.argument<String>("content") ?: ""
                    val isResting = call.argument<Boolean>("isResting") ?: false

                    startWorkoutService(title, content, isResting)
                    result.success(null)
                }
                "stopService" -> {
                    stopWorkoutService()
                    result.success(null)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "Treino em andamento"
                    val content = call.argument<String>("content") ?: ""
                    val isResting = call.argument<Boolean>("isResting") ?: false

                    updateWorkoutNotification(title, content, isResting)
                    result.success(null)
                }
                "startRestTimer" -> {
                    val seconds = call.argument<Int>("seconds") ?: 60
                    val exerciseName = call.argument<String>("exerciseName") ?: "Exercício"
                    val currentSet = call.argument<Int>("currentSet") ?: 1
                    val totalSets = call.argument<Int>("totalSets") ?: 3

                    startRestTimer(seconds, exerciseName, currentSet, totalSets)
                    result.success(null)
                }
                "stopRestTimer" -> {
                    stopRestTimer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchService(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun startWorkoutService(title: String, content: String, isResting: Boolean) {
        val intent = Intent(this, WorkoutForegroundService::class.java).apply {
            action = WorkoutForegroundService.ACTION_START
            putExtra("title", title)
            putExtra("content", content)
            putExtra("isResting", isResting)
        }
        launchService(intent)
    }

    private fun stopWorkoutService() {
        val intent = Intent(this, WorkoutForegroundService::class.java).apply {
            action = WorkoutForegroundService.ACTION_STOP
        }
        // stop does not need FGS promotion
        startService(intent)
    }

    private fun updateWorkoutNotification(title: String, content: String, isResting: Boolean) {
        val intent = Intent(this, WorkoutForegroundService::class.java).apply {
            action = WorkoutForegroundService.ACTION_UPDATE
            putExtra("title", title)
            putExtra("content", content)
            putExtra("isResting", isResting)
        }
        launchService(intent)
    }

    private fun startRestTimer(seconds: Int, exerciseName: String, currentSet: Int, totalSets: Int) {
        val intent = Intent(this, WorkoutForegroundService::class.java).apply {
            action = WorkoutForegroundService.ACTION_START_REST
            putExtra("seconds", seconds)
            putExtra("exerciseName", exerciseName)
            putExtra("currentSet", currentSet)
            putExtra("totalSets", totalSets)
        }
        launchService(intent)
    }

    private fun stopRestTimer() {
        val intent = Intent(this, WorkoutForegroundService::class.java).apply {
            action = WorkoutForegroundService.ACTION_STOP_REST_SILENT
        }
        startService(intent)
    }
}
