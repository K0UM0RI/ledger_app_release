package com.koumori.ledger

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val updaterChannel = "com.koumori.ledger/updater"
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceUpdateInfo" -> {
                        ioExecutor.execute {
                            try {
                                val supportedAbis = Build.SUPPORTED_ABIS?.toList() ?: emptyList()
                                val primaryAbi = supportedAbis.firstOrNull() ?: ""
                                val sourceApkPath = applicationInfo.sourceDir ?: ""
                                val installedSha256 = if (sourceApkPath.isNotEmpty() && File(sourceApkPath).exists()) {
                                    sha256File(File(sourceApkPath))
                                } else {
                                    ""
                                }
                                val payload = mapOf(
                                    "primaryAbi" to primaryAbi,
                                    "supportedAbis" to supportedAbis,
                                    "sourceApkPath" to sourceApkPath,
                                    "installedApkSha256" to installedSha256
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("DEVICE_INFO_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    "computeFileSha256" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARG", "Missing file path", null)
                            return@setMethodCallHandler
                        }
                        ioExecutor.execute {
                            try {
                                val file = File(path)
                                if (!file.exists()) {
                                    runOnUiThread {
                                        result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                                    }
                                    return@execute
                                }
                                val hash = sha256File(file)
                                runOnUiThread { result.success(hash) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("HASH_ERROR", e.message, null)
                                }
                            }
                        }
                    }

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARG", "Missing APK path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                !packageManager.canRequestPackageInstalls()
                            ) {
                                val settingsIntent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(settingsIntent)
                                result.success("PERMISSION_REQUIRED")
                                return@setMethodCallHandler
                            }

                            val apkFile = File(path)
                            if (!apkFile.exists()) {
                                result.error("FILE_NOT_FOUND", "APK file not found: $path", null)
                                return@setMethodCallHandler
                            }

                            val apkUri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.ota_update_provider",
                                apkFile
                            )
                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(installIntent)
                            result.success("OK")
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun sha256File(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(64 * 1024)
        FileInputStream(file).use { input ->
            var read = input.read(buffer)
            while (read > 0) {
                digest.update(buffer, 0, read)
                read = input.read(buffer)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
