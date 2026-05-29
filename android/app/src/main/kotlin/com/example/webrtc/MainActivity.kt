package com.example.webrtc

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MediaProjectionService.CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startProjectionService" -> {
                    val intent = Intent(this, MediaProjectionService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }

                "stopProjectionService" -> {
                    stopService(Intent(this, MediaProjectionService::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
