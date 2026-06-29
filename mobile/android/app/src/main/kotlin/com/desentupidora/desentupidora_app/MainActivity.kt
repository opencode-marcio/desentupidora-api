package com.desentupidora.desentupidora_app

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.desentupidora.app/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendPdfToWhatsApp" -> {
                    val pdfPath = call.argument<String>("pdfPath")
                    val phone = call.argument<String>("phone")
                    if (pdfPath != null && phone != null) {
                        sendPdfToWhatsApp(pdfPath, phone)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "pdfPath and phone required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendPdfToWhatsApp(pdfPath: String, phone: String) {
        val file = File(pdfPath)
        if (!file.exists()) return

        val pdfUri: Uri = FileProvider.getUriForFile(
            this,
            "${packageName}.fileprovider",
            file
        )

        // phone from Dart does NOT include country code (e.g., "11999999999")
        val fullPhone = "55$phone"
        val jid = "${fullPhone}@s.whatsapp.net"

        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, pdfUri)
            putExtra("jid", jid)
            putExtra("address", fullPhone)
            putExtra("com.whatsapp.extra.CONTACT", fullPhone)
            putExtra(Intent.EXTRA_PHONE_NUMBER, fullPhone)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        // Find WhatsApp package dynamically
        val pm = packageManager
        val waPackages = pm.queryIntentActivities(sendIntent, 0)
            .map { it.activityInfo.packageName }
            .distinct()
            .filter { pkg ->
                pkg.contains("whatsapp", ignoreCase = true) ||
                pkg.contains("gbwa", ignoreCase = true)
            }

        var sent = false
        for (pkg in waPackages) {
            try {
                val waIntent = Intent(sendIntent).apply { `package` = pkg }
                startActivity(waIntent)
                sent = true
                break
            } catch (_: Exception) { }
        }

        if (!sent) {
            // Fallback: try known package names
            val fallbackPackages = listOf(
                "com.whatsapp", "com.whatsapp.w4b",
                "com.gbwhatsapp", "com.gbwhatsapp.gbwhatsapp",
                "com.gbwhatsapp.gbw"
            )
            for (pkg in fallbackPackages) {
                try {
                    val waIntent = Intent(sendIntent).apply { `package` = pkg }
                    startActivity(waIntent)
                    sent = true
                    break
                } catch (_: Exception) { }
            }
        }

        if (!sent) {
            // Last resort: generic share
            try {
                startActivity(Intent.createChooser(sendIntent, "Enviar relatório via"))
            } catch (_: Exception) { }
        }
    }
}
