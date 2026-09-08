package com.shehablotfallah.finlens

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main activity for Finlens.
 *
 * IMPORTANT: Extends FlutterFragmentActivity (NOT FlutterActivity) because
 * the `local_auth` plugin requires a FragmentActivity to show the
 * BiometricPrompt on Android. Without this, biometric authentication
 * silently fails with "Biometric authentication is not available."
 *
 * Security note on FLAG_SECURE:
 * We deliberately do NOT set FLAG_SECURE on the running window — that flag
 * also blocks in-app screenshots during normal use, which the spec explicitly
 * rejects.
 *
 * Instead, we set FLAG_SECURE ONLY when the app is being sent to the
 * background (onPause / onStop) and clear it again on resume, so that the
 * OS Recent-Apps app-switcher thumbnail shows a black screen (banking-app
 * behavior), but the user can still take screenshots while the app is
 * foregrounded.
 */
class MainActivity : FlutterFragmentActivity() {

    private val secureChannel = "com.shehablotfallah.finlens/secure"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureForBackground" -> {
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
