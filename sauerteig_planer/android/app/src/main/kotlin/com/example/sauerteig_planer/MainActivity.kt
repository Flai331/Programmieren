package com.example.sauerteig_planer

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.sauerteig_planer/widget"
    private var pendingScreen: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingScreen" -> {
                        val screen = pendingScreen
                        pendingScreen = null
                        result.success(screen)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
        // Flutter-Seite informieren falls Engine bereits läuft
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            val screen = pendingScreen
            if (screen != null) {
                MethodChannel(messenger, channel).invokeMethod("openScreen", screen)
                pendingScreen = null
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        val screen = intent?.getStringExtra("open_screen")
        if (screen != null) {
            pendingScreen = screen
        }
    }
}
