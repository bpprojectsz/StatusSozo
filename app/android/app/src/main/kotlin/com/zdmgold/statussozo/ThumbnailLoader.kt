package com.zdmgold.statussozo

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.LruCache
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * Decodes small JPEG thumbnails on a fixed pool of three threads, with a 16 MB
 * least-recently-used cache. Returns null instead of throwing when a file
 * cannot be decoded.
 */
class ThumbnailLoader(private val context: Context) {
    companion object {
        private const val THREADS = 3
        private const val CACHE_BYTES = 16 * 1024 * 1024
        private const val JPEG_QUALITY = 80
    }

    private val pool: ExecutorService = Executors.newFixedThreadPool(THREADS)

    private val cache = object : LruCache<String, ByteArray>(CACHE_BYTES) {
        override fun sizeOf(key: String, value: ByteArray): Int = value.size
    }

    /** Decodes in the background and calls [onDone] on a pool thread. */
    fun load(uriString: String, mime: String, px: Int, onDone: (ByteArray?) -> Unit) {
        val key = "$uriString:$px"
        val hit = cache.get(key)
        if (hit != null) {
            onDone(hit)
            return
        }
        try {
            pool.execute {
                val bytes = try {
                    decode(uriString, mime, px)
                } catch (error: Throwable) {
                    null
                }
                if (bytes != null) {
                    cache.put(key, bytes)
                }
                onDone(bytes)
            }
        } catch (error: Exception) {
            onDone(null)
        }
    }

    fun dispose() {
        pool.shutdownNow()
        cache.evictAll()
    }

    private fun decode(uriString: String, mime: String, px: Int): ByteArray? {
        val uri = Uri.parse(uriString)
        val source = if (mime.startsWith("video/")) videoFrame(uri) else imageBitmap(uri, px)
        if (source == null) {
            return null
        }
        val scaled = scaleToLongestEdge(source, px)
        val output = ByteArrayOutputStream()
        val ok = scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)
        if (scaled !== source) {
            scaled.recycle()
        }
        source.recycle()
        return if (ok) output.toByteArray() else null
    }

    private fun imageBitmap(uri: Uri, px: Int): Bitmap? {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options()
        bounds.inJustDecodeBounds = true
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return null
        }
        val longest = max(bounds.outWidth, bounds.outHeight)
        var sample = 1
        while (longest / (sample * 2) >= px) {
            sample *= 2
        }
        val options = BitmapFactory.Options()
        options.inSampleSize = sample
        val decoded = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        } ?: return null
        val rotation = exifRotation(uri)
        if (rotation == 0) {
            return decoded
        }
        val matrix = Matrix()
        matrix.postRotate(rotation.toFloat())
        val rotated = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (rotated !== decoded) {
            decoded.recycle()
        }
        return rotated
    }

    private fun exifRotation(uri: Uri): Int {
        return try {
            context.contentResolver.openInputStream(uri)?.use {
                val orientation = ExifInterface(it).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
                when (orientation) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270
                    else -> 0
                }
            } ?: 0
        } catch (error: Exception) {
            0
        }
    }

    private fun videoFrame(uri: Uri): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } catch (error: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (error: Exception) {
                // Nothing left to release.
            }
        }
    }

    private fun scaleToLongestEdge(bitmap: Bitmap, px: Int): Bitmap {
        val longest = max(bitmap.width, bitmap.height)
        if (longest <= px) {
            return bitmap
        }
        val factor = px.toFloat() / longest.toFloat()
        val width = max(1, Math.round(bitmap.width * factor))
        val height = max(1, Math.round(bitmap.height * factor))
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }
}
