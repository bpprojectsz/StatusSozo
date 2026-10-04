package com.zdmgold.statussozo

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import java.io.FileNotFoundException
import java.io.IOException

/**
 * Saves into MediaStore so items appear in the gallery, lists what this app
 * saved, and deletes it again. On API 29 and above an app sees and manages its
 * own files without any storage permission.
 */
class GallerySaver(private val context: Context) {
    private val resolver = context.contentResolver

    private fun collection(isVideo: Boolean): Uri =
        if (isVideo) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }

    private fun root(isVideo: Boolean): String =
        if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES

    fun save(sourceUri: String, name: String, mime: String, subfolder: String): Map<String, Any?> {
        val isVideo = mime.startsWith("video/")
        val values = ContentValues()
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name)
        values.put(MediaStore.MediaColumns.MIME_TYPE, mime)
        values.put(MediaStore.MediaColumns.RELATIVE_PATH, "${root(isVideo)}/$subfolder")
        values.put(MediaStore.MediaColumns.IS_PENDING, 1)

        val target = resolver.insert(collection(isVideo), values)
            ?: throw NativeException(ErrorCodes.IO, "Could not create the gallery entry")

        try {
            val input = resolver.openInputStream(Uri.parse(sourceUri))
                ?: throw NativeException(ErrorCodes.NOT_FOUND, "The source could not be opened")
            input.use { source ->
                val output = resolver.openOutputStream(target)
                    ?: throw NativeException(ErrorCodes.IO, "Could not open the gallery entry")
                output.use { sink ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) {
                            break
                        }
                        sink.write(buffer, 0, read)
                    }
                }
            }
            val done = ContentValues()
            done.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(target, done, null, null)
        } catch (error: Throwable) {
            try {
                resolver.delete(target, null, null)
            } catch (ignored: Exception) {
                // Best effort: the half-written row may already be gone.
            }
            throw when (error) {
                is NativeException -> error
                is SecurityException -> NativeException(ErrorCodes.ACCESS_LOST, error.message, error)
                is FileNotFoundException -> NativeException(ErrorCodes.NOT_FOUND, error.message, error)
                is IOException -> NativeException(ErrorCodes.IO, error.message, error)
                else -> NativeException(ErrorCodes.IO, error.message, error)
            }
        }
        return describe(target) ?: throw NativeException(ErrorCodes.IO, "The saved item could not be read back")
    }

    fun listSaved(subfolder: String): List<Map<String, Any?>> {
        val rows = ArrayList<Map<String, Any?>>()
        for (isVideo in listOf(false, true)) {
            val base = collection(isVideo)
            val projection = arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.MIME_TYPE,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATE_ADDED,
            )
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            val args = arrayOf("${root(isVideo)}/$subfolder/%")
            try {
                val cursor = resolver.query(base, projection, selection, args, null)
                    ?: throw NativeException(ErrorCodes.IO, "The gallery could not be queried")
                cursor.use {
                    while (it.moveToNext()) {
                        rows.add(row(base, it.getLong(0), it.getString(1), it.getString(2), it.getLong(3), it.getLong(4)))
                    }
                }
            } catch (error: SecurityException) {
                throw NativeException(ErrorCodes.IO, error.message, error)
            }
        }
        return rows
    }

    /** Returns true when a row was deleted. */
    fun delete(uriString: String): Boolean {
        return try {
            resolver.delete(Uri.parse(uriString), null, null) > 0
        } catch (error: SecurityException) {
            throw NativeException(ErrorCodes.PERMISSION_LOST, error.message, error)
        }
    }

    private fun describe(uri: Uri): Map<String, Any?>? {
        val projection = arrayOf(
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        val cursor = resolver.query(uri, projection, null, null, null) ?: return null
        cursor.use {
            if (!it.moveToFirst()) {
                return null
            }
            return hashMapOf<String, Any?>(
                "uri" to uri.toString(),
                "name" to it.getString(0),
                "mime" to it.getString(1),
                "size" to it.getLong(2),
                "added" to it.getLong(3) * 1000L,
            )
        }
    }

    private fun row(
        base: Uri,
        id: Long,
        name: String?,
        mime: String?,
        size: Long,
        addedSeconds: Long,
    ): Map<String, Any?> =
        hashMapOf<String, Any?>(
            "uri" to ContentUris.withAppendedId(base, id).toString(),
            "name" to (name ?: ""),
            "mime" to (mime ?: ""),
            "size" to size,
            "added" to addedSeconds * 1000L,
        )
}
