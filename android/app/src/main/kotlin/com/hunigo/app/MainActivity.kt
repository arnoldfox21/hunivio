package com.hunigo.app

import android.accounts.AccountManager
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.hunigo.app/google_auth"
        private const val REQ_PICK_GOOGLE_ACCOUNT = 9001
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickGoogleAccount" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "Pemilihan akun Google sedang berlangsung", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        try {
                            @Suppress("DEPRECATION")
                            val intent = AccountManager.newChooseAccountIntent(
                                null,
                                null,
                                arrayOf("com.google"),
                                true,
                                null,
                                null,
                                null,
                                null
                            )
                            startActivityForResult(intent, REQ_PICK_GOOGLE_ACCOUNT)
                        } catch (e: Exception) {
                            pendingResult = null
                            result.error("LAUNCH_ERROR", e.localizedMessage, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_PICK_GOOGLE_ACCOUNT) {
            val callback = pendingResult
            pendingResult = null
            if (callback != null) {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val email = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                        ?.trim()
                        ?.lowercase()
                    if (!email.isNullOrEmpty()) {
                        val googleId = "google_${email.replace(Regex("[^a-z0-9]"), "_")}"
                        val displayName = deriveDisplayName(email)

                        val payload = hashMapOf<String, String>(
                            "googleId" to googleId,
                            "email" to email,
                            "name" to displayName,
                            "avatarUrl" to ""
                        )
                        callback.success(payload)
                        return
                    }
                }
                // User membatalkan dialog pemilihan akun Google
                callback.success(null)
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun deriveDisplayName(email: String): String {
        val localPart = email.substringBefore("@")
        val words = localPart
            .replace(Regex("[._-]+"), " ")
            .replace(Regex("\\d+$"), "")
            .trim()
            .split(Regex("\\s+"))
            .filter { it.isNotEmpty() }
        if (words.isEmpty()) {
            return localPart.replaceFirstChar { it.uppercase() }
        }
        return words.joinToString(" ") { word ->
            word.lowercase().replaceFirstChar { it.uppercase() }
        }
    }
}
