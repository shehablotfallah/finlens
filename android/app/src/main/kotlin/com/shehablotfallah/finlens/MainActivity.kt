package com.shehablotfallah.finlens

import android.app.ActivityManager
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main activity for Finlens.
 *
 * Security note on FLAG_SECURE:
 * We deliberately do NOT set FLAG_SECURE on the running window — that flag also
 * blocks in-app screenshots during normal use, which the spec explicitly rejects.
 *
 * Instead, we set FLAG_SECURE ONLY when the app is being sent to the background
 * (onPause / onStop) and clear it again on resume, so that the OS Recent-Apps
 * app-switcher thumbnail shows a black screen (banking-app behavior), but the
 * user can still take screenshots while the app is foregrounded.
 */
class MainActivity : FlutterActivity() {

    private val secureChannel = "com.shehablotfallah.finlens/secure"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureForBackground" -> {
                        // Toggling handled by lifecycle below. No-op from Dart.
                        result.success(true)
                    }
                    "isInRecentTasks" -> {
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPause() {
        super.onPause()
        // Block the OS snapshot taken when app goes to recents.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun onResume() {
        super.onResume()
        // Clear FLAG_SECURE so the user CAN screenshot inside the app.
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
