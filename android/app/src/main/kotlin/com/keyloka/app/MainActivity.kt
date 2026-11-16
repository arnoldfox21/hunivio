package com.keyloka.app

import android.Manifest
import android.accounts.Account
import android.accounts.AccountManager
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.api.signin.GoogleSignIn
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.keyloka.app/google_auth"
        private const val REQ_PICK_GOOGLE_ACCOUNT = 9001
        private const val REQ_GET_ACCOUNTS_PERMISSION = 9002
    }

    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingAccountsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getGoogleAccounts" -> {
                        handleGetGoogleAccounts(result)
                    }
                    "pickGoogleAccount" -> {
                        if (pendingPickResult != null) {
                            result.error("BUSY", "Pemilihan akun Google sedang berlangsung", null)
                            return@setMethodCallHandler
                        }
                        pendingPickResult = result
                        try {
                            val intent = buildSystemAccountPickerIntent()
                            startActivityForResult(intent, REQ_PICK_GOOGLE_ACCOUNT)
                        } catch (e: Exception) {
                            pendingPickResult = null
                            result.error("LAUNCH_ERROR", e.localizedMessage, null)
                        }
                    }
                    "refreshGoogleAccount" -> {
                        val email = call.argument<String>("email")?.trim()?.lowercase()
                        if (email.isNullOrEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val accounts = AccountManager.get(applicationContext).getAccountsByType("com.google")
                        val stillExists = accounts.any { it.name.trim().equals(email, ignoreCase = true) }
                        if (!stillExists) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val payload = resolveGoogleAccountProfile(email, fetchRemote = true)
                            runOnUiThread {
                                result.success(payload)
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.keyloka.app/launcher")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openExternalUrl" -> {
                        val url = call.argument<String>("url")?.trim()
                        if (url.isNullOrEmpty()) {
                            result.error("INVALID_URL", "URL kosong", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LAUNCH_ERROR", e.localizedMessage ?: "Gagal membuka URL", null)
                        }
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text")?.trim()
                        val subject = call.argument<String>("subject")?.trim()
                        if (text.isNullOrEmpty()) {
                            result.error("INVALID_TEXT", "Teks kosong", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                                if (!subject.isNullOrEmpty()) {
                                    putExtra(Intent.EXTRA_SUBJECT, subject)
                                }
                            }
                            val chooser = Intent.createChooser(sendIntent, subject ?: "Bagikan Properti")
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(chooser)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.localizedMessage ?: "Gagal membagikan", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleGetGoogleAccounts(result: MethodChannel.Result) {
        val accountManager = AccountManager.get(applicationContext)
        val existingAccounts = accountManager.getAccountsByType("com.google")
        if (existingAccounts.isNotEmpty()) {
            resolveAccountsAsync(existingAccounts, result)
            return
        }

        val hasGetAccounts = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.GET_ACCOUNTS
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasGetAccounts) {
            if (pendingAccountsResult != null) {
                result.error("BUSY", "Sedang meminta izin akses akun", null)
                return
            }
            pendingAccountsResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.GET_ACCOUNTS),
                REQ_GET_ACCOUNTS_PERMISSION
            )
            return
        }

        resolveAccountsAsync(existingAccounts, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQ_GET_ACCOUNTS_PERMISSION) {
            val callback = pendingAccountsResult
            pendingAccountsResult = null
            if (callback != null) {
                val accounts = AccountManager.get(applicationContext).getAccountsByType("com.google")
                resolveAccountsAsync(accounts, callback)
                return
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun resolveAccountsAsync(accounts: Array<Account>, result: MethodChannel.Result) {
        if (accounts.isEmpty()) {
            result.success(emptyList<HashMap<String, String>>())
            return
        }
        Thread {
            val resolvedList = accounts.mapNotNull { account ->
                val email = account.name.trim().lowercase()
                if (email.isEmpty()) null else resolveGoogleAccountProfile(email, fetchRemote = false)
            }
            runOnUiThread {
                result.success(resolvedList)
            }
        }.start()
    }

    /**
     * Fallback ke pemilih akun Google sistem Android (AccountManager)
     * yang selalu diizinkan untuk aplikasi pihak ketiga.
     */
    private fun buildSystemAccountPickerIntent(): Intent {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return AccountManager.newChooseAccountIntent(
                null,
                null,
                arrayOf("com.google"),
                null,
                null,
                null,
                null
            )
        }
        @Suppress("DEPRECATION")
        return AccountManager.newChooseAccountIntent(
            null,
            null,
            arrayOf("com.google"),
            true,
            null,
            null,
            null,
            null
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_PICK_GOOGLE_ACCOUNT) {
            val callback = pendingPickResult
            pendingPickResult = null
            if (callback != null) {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val email = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                        ?.trim()
                        ?.lowercase()
                    if (!email.isNullOrEmpty()) {
                        Thread {
                            val payload = resolveGoogleAccountProfile(email, fetchRemote = true)
                            runOnUiThread {
                                callback.success(payload)
                            }
                        }.start()
                        return
                    }
                }
                callback.success(null)
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun resolveGoogleAccountProfile(
        email: String,
        fetchRemote: Boolean = true
    ): HashMap<String, String> {
        var googleId = "google_${email.replace(Regex("[^a-z0-9]"), "_")}"
        var displayName = deriveDisplayName(email)
        var avatarUrl = ""
        var accessToken = ""

        // 1. Cek jika ada sesi GoogleSignInAccount yang tersimpan untuk email ini
        try {
            val lastAccount = GoogleSignIn.getLastSignedInAccount(applicationContext)
            if (lastAccount != null && lastAccount.email?.equals(email, ignoreCase = true) == true) {
                if (!lastAccount.id.isNullOrBlank()) {
                    googleId = lastAccount.id!!
                }
                if (!lastAccount.displayName.isNullOrBlank()) {
                    displayName = lastAccount.displayName!!
                }
                if (lastAccount.photoUrl != null) {
                    avatarUrl = lastAccount.photoUrl.toString()
                }
            }
        } catch (_: Exception) {
        }

        // 2. Ambil Google Account ID dari GoogleAuthUtil bila tersedia
        if (fetchRemote) {
            try {
                val id = GoogleAuthUtil.getAccountId(applicationContext, email)
                if (!id.isNullOrBlank()) {
                    googleId = id
                }
            } catch (_: Exception) {
            }

            // 3. Coba ambil foto profil & nama asli dari endpoint Google userinfo jika token diizinkan
            try {
                val account = Account(email, "com.google")
                val scope = "oauth2:https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email"
                val token = GoogleAuthUtil.getToken(applicationContext, account, scope)
                if (!token.isNullOrBlank()) {
                    accessToken = token
                    val url = URL("https://www.googleapis.com/oauth2/v3/userinfo")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        connectTimeout = 3000
                        readTimeout = 3000
                        setRequestProperty("Authorization", "Bearer $token")
                    }
                    if (conn.responseCode in 200..299) {
                        val body = conn.inputStream.bufferedReader().use { it.readText() }
                        val json = JSONObject(body)
                        val sub = json.optString("sub", "").trim()
                        val name = json.optString("name", "").trim()
                        val picture = json.optString("picture", "").trim()
                        if (sub.isNotEmpty()) googleId = sub
                        if (name.isNotEmpty()) displayName = name
                        if (picture.isNotEmpty()) avatarUrl = picture
                    }
                    conn.disconnect()
                }
            } catch (_: Exception) {
                // Abaikan jika OAuth consent masih dibatasi
            }
        }

        // 4. Cek ContactsContract Profile lokal bila nama masih default
        if (displayName == deriveDisplayName(email)) {
            try {
                contentResolver.query(
                    ContactsContract.Profile.CONTENT_URI,
                    arrayOf(ContactsContract.Profile.DISPLAY_NAME_PRIMARY),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val localName = cursor.getString(0)?.trim()
                        if (!localName.isNullOrEmpty() && !localName.contains("@")) {
                            displayName = localName.split(Regex("\\s+")).joinToString(" ") { w ->
                                w.lowercase().replaceFirstChar { it.uppercase() }
                            }
                        }
                    }
                }
            } catch (_: Exception) {
            }
        }

        // 5. Pastikan selalu ada foto profil (avatarUrl) yang valid untuk disimpan saat sign up
        if (avatarUrl.isBlank()) {
            val encodedName = URLEncoder.encode(displayName, "UTF-8")
            avatarUrl = "https://ui-avatars.com/api/?name=$encodedName&background=1BAA56&color=ffffff&size=256&bold=true&format=png"
        }

        return hashMapOf(
            "googleId" to googleId,
            "email" to email,
            "name" to displayName,
            "avatarUrl" to avatarUrl,
            "accessToken" to accessToken
        )
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
