package com.zdmgold.statussozo

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import java.io.FileNotFoundException

/**
 * Lists a granted folder with a single content-resolver query, which is much
 * faster than walking DocumentFile objects.
 */
object FolderLister {
    fun list(resolver: ContentResolver, treeUriString: String): List<Map<String, Any?>> {
        val treeUri = Uri.parse(treeUriString)
        val documentId = try {
            DocumentsContract.getTreeDocumentId(treeUri)
        } catch (error: IllegalArgumentException) {
            throw NativeException(ErrorCodes.NOT_FOUND, "Not a folder tree URI", error)
        }
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val rows = ArrayList<Map<String, Any?>>()
        try {
            val cursor = resolver.query(children, projection, null, null, null)
                ?: throw NativeException(ErrorCodes.IO, "The folder could not be queried")
            cursor.use {
                while (it.moveToNext()) {
                    val id = it.getString(0) ?: continue
                    val name = it.getString(1) ?: continue
                    val mime = it.getString(2) ?: continue
                    if (name == ".nomedia") {
                        continue
                    }
                    if (!mime.startsWith("image/") && !mime.startsWith("video/")) {
                        continue
                    }
                    val size = if (it.isNull(3)) 0L else it.getLong(3)
                    val modified = if (it.isNull(4)) 0L else it.getLong(4)
                    rows.add(
                        hashMapOf<String, Any?>(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(treeUri, id).toString(),
                            "name" to name,
                            "mime" to mime,
                            "size" to size,
                            "modified" to modified,
                        ),
                    )
                }
            }
        } catch (error: NativeException) {
            throw error
        } catch (error: SecurityException) {
            throw NativeException(ErrorCodes.ACCESS_LOST, error.message, error)
        } catch (error: FileNotFoundException) {
            throw NativeException(ErrorCodes.NOT_FOUND, error.message, error)
        } catch (error: IllegalArgumentException) {
            throw NativeException(ErrorCodes.NOT_FOUND, error.message, error)
        }
        return rows
    }
}
