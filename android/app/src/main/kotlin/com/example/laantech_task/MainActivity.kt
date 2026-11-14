package com.example.laantech_task

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "laantech_task/public_downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "publishToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val sourcePath = call.argument<String>("sourcePath")
                val fileName = call.argument<String>("fileName")
                val relativePath =
                    call.argument<String>("relativePath") ?: "Download/POS_Transfers"

                if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                    result.error("bad_args", "sourcePath and fileName required", null)
                    return@setMethodCallHandler
                }

                try {
                    val displayPath = publishFile(sourcePath, fileName, relativePath)
                    result.success(
                        mapOf(
                            "displayPath" to displayPath,
                        ),
                    )
                } catch (e: Exception) {
                    result.error("publish_failed", e.message, null)
                }
            }
    }

    private fun publishFile(
        sourcePath: String,
        fileName: String,
        relativePath: String,
    ): String {
        val mime = guessMime(fileName)
        val source = File(sourcePath)
        if (!source.exists()) {
            throw IllegalStateException("Source file missing")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val collection =
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore insert failed")

            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Unable to open MediaStore stream")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            return "Downloads/POS_Transfers/$fileName"
        }

        val downloads =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val folder = File(downloads, "POS_Transfers")
        if (!folder.exists() && !folder.mkdirs()) {
            throw IllegalStateException("Unable to create Downloads/POS_Transfers")
        }

        val dest = File(folder, fileName)
        FileInputStream(source).use { input ->
            FileOutputStream(dest).use { output -> input.copyTo(output) }
        }
        return "Downloads/POS_Transfers/$fileName"
    }

    private fun guessMime(fileName: String): String {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        if (ext.isEmpty()) return "application/octet-stream"
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"
    }
}
