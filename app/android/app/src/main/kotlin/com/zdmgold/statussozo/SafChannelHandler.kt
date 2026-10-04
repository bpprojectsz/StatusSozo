package com.zdmgold.statussozo

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Routes every method of the statussozo/saf channel to its helper. Everything
 * except the picker and thumbnails runs on a small background executor, and
 * every reply is posted back to the main thread. No exception can reach the
 * Flutter engine: each is converted to one of the [ErrorCodes].
 */
class SafChannelHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "statussozo/saf"
    }

    private val main = Handler(Looper.getMainLooper())
    private val background: ExecutorService = Executors.newFixedThreadPool(2)
    private val appContext = activity.applicationContext
    private val folderAccess = FolderAccess(activity)
    private val thumbnails = ThumbnailLoader(appContext)
    private val saver = GallerySaver(appContext)
    private val shareCache = ShareCache(appContext)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickFolder" -> folderAccess.pick(call.argument<String>("initialUri"), result)
                "thumbnail" -> thumbnail(call, result)
                "hasAccess" -> async(result) { folderAccess.hasAccess(text(call, "uri")) }
                "releaseFolder" -> async(result) {
                    folderAccess.release(text(call, "uri"))
                    null
                }
                "listFolder" -> async(result) {
                    FolderLister.list(appContext.contentResolver, text(call, "uri"))
                }
                "readBytes" -> async(result) {
                    readBytes(text(call, "uri"), number(call, "maxBytes"))
                }
                "saveToGallery" -> async(result) {
                    saver.save(
                        text(call, "uri"),
                        text(call, "name"),
                        text(call, "mime"),
                        text(call, "subfolder"),
                    )
                }
                "listSaved" -> async(result) { saver.listSaved(text(call, "subfolder")) }
                "deleteSaved" -> async(result) { saver.delete(text(call, "uri")) }
                "copyToCache" -> async(result) {
                    shareCache.copy(text(call, "uri"), text(call, "name"))
                }
                "pruneShareCache" -> async(result) {
                    shareCache.prune(number(call, "olderThanMs"))
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error(codeFor(error), error.message, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        folderAccess.onActivityResult(requestCode, resultCode, data)
    }

    fun dispose() {
        background.shutdownNow()
        thumbnails.dispose()
    }

    private fun thumbnail(call: MethodCall, result: MethodChannel.Result) {
        val uri = text(call, "uri")
        val mime = text(call, "mime")
        val px = number(call, "px").toInt()
        thumbnails.load(uri, mime, px) { bytes ->
            main.post { result.success(bytes) }
        }
    }

    private fun readBytes(uri: String, maxBytes: Long): ByteArray {
        val input = appContext.contentResolver.openInputStream(android.net.Uri.parse(uri))
            ?: throw NativeException(ErrorCodes.NOT_FOUND, "The source could not be opened")
        input.use { stream ->
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0L
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) {
                    break
                }
                total += read
                if (total > maxBytes) {
                    throw NativeException(ErrorCodes.TOO_LARGE, "The file is larger than $maxBytes bytes")
                }
                output.write(buffer, 0, read)
            }
            return output.toByteArray()
        }
    }

    private fun async(result: MethodChannel.Result, block: () -> Any?) {
        try {
            background.execute {
                try {
                    val value = block()
                    main.post { result.success(value) }
                } catch (error: Throwable) {
                    val code = codeFor(error)
                    val message = error.message
                    main.post { result.error(code, message, null) }
                }
            }
        } catch (error: Exception) {
            result.error(ErrorCodes.IO, error.message, null)
        }
    }

    private fun codeFor(error: Throwable): String =
        when (error) {
            is NativeException -> error.code
            is SecurityException -> ErrorCodes.ACCESS_LOST
            is FileNotFoundException -> ErrorCodes.NOT_FOUND
            is IOException -> ErrorCodes.IO
            else -> ErrorCodes.IO
        }

    private fun text(call: MethodCall, key: String): String =
        call.argument<String>(key)
            ?: throw NativeException(ErrorCodes.IO, "Missing argument: $key")

    private fun number(call: MethodCall, key: String): Long =
        call.argument<Number>(key)?.toLong()
            ?: throw NativeException(ErrorCodes.IO, "Missing argument: $key")
}
