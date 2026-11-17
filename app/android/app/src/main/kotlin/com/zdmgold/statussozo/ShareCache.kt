package com.zdmgold.statussozo

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileNotFoundException
import java.util.UUID

/**
 * Stages files in the cache folder so the share sheet reads plain files, and
 * prunes old staging copies.
 */
class ShareCache(private val context: Context) {
    private val root: File
        get() = File(context.cacheDir, "share")

    /** Copies [uriString] into the share cache and returns the absolute path. */
    fun copy(uriString: String, name: String): String {
        val directory = File(root, UUID.randomUUID().toString())
        if (!directory.mkdirs()) {
            throw NativeException(ErrorCodes.IO, "Could not create the share folder")
        }
        val target = File(directory, sanitise(name))
        try {
            val input = context.contentResolver.openInputStream(Uri.parse(uriString))
                ?: throw NativeException(ErrorCodes.NOT_FOUND, "The source could not be opened")
            input.use { source ->
                target.outputStream().use { sink ->
                    source.copyTo(sink, 64 * 1024)
                }
            }
        } catch (error: NativeException) {
            directory.deleteRecursively()
            throw error
        } catch (error: SecurityException) {
            directory.deleteRecursively()
            throw NativeException(ErrorCodes.ACCESS_LOST, error.message, error)
        } catch (error: FileNotFoundException) {
            directory.deleteRecursively()
            throw NativeException(ErrorCodes.NOT_FOUND, error.message, error)
        } catch (error: Exception) {
            directory.deleteRecursively()
            throw NativeException(ErrorCodes.IO, error.message, error)
        }
        return target.absolutePath
    }

    /** Total size in bytes of every staged file. */
    fun size(): Long =
        root.walkTopDown().filter { it.isFile }.sumOf { it.length() }

    /** Deletes every staged file and returns how many. */
    fun clear(): Int {
        var deleted = 0
        for (entry in root.walkBottomUp()) {
            if (entry == root) {
                continue
            }
            if (entry.isFile) {
                if (entry.delete()) {
                    deleted++
                }
            } else {
                entry.delete()
            }
        }
        return deleted
    }

    /**
     * Deletes staged files older than [olderThanMs] and returns how many. When
     * [maxBytes] is above zero, the oldest staging folders are then deleted
     * until the total is at or under it.
     */
    fun prune(olderThanMs: Long, maxBytes: Long = 0L): Int {
        val cutoff = System.currentTimeMillis() - olderThanMs
        var deleted = 0
        val directories = root.listFiles() ?: return 0
        for (directory in directories) {
            if (!directory.isDirectory) {
                if (directory.lastModified() < cutoff && directory.delete()) {
                    deleted++
                }
                continue
            }
            val files = directory.listFiles() ?: emptyArray()
            for (file in files) {
                if (file.lastModified() < cutoff && file.delete()) {
                    deleted++
                }
            }
            val remaining = directory.listFiles()
            if (remaining == null || remaining.isEmpty()) {
                directory.delete()
            }
        }
        if (maxBytes > 0L) {
            var total = size()
            val oldestFirst = (root.listFiles() ?: emptyArray()).sortedBy { newestStamp(it) }
            for (entry in oldestFirst) {
                if (total <= maxBytes) {
                    break
                }
                val files = entry.walkTopDown().filter { it.isFile }.toList()
                val bytes = files.sumOf { it.length() }
                if (entry.deleteRecursively()) {
                    total -= bytes
                    deleted += files.size
                }
            }
        }
        return deleted
    }

    private fun newestStamp(entry: File): Long =
        entry.walkTopDown().filter { it.isFile }.maxOfOrNull { it.lastModified() }
            ?: entry.lastModified()

    private fun sanitise(name: String): String {
        val cleaned = name.replace(Regex("[^A-Za-z0-9._ -]"), "_").trim().trim('.')
        return if (cleaned.isEmpty()) "file" else cleaned.take(120)
    }
}
