package com.zdmgold.statussozo

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel

/**
 * The system folder picker and the persisted permissions it produces.
 */
class FolderAccess(private val activity: Activity) {
    companion object {
        const val REQUEST_PICK = 4101
    }

    private var pending: MethodChannel.Result? = null

    /** Opens the picker. Must be called on the main thread. */
    fun pick(initialUri: String?, result: MethodChannel.Result) {
        if (pending != null) {
            result.error(ErrorCodes.IO, "A folder picker is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        if (initialUri != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialUri))
        }
        pending = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (error: Exception) {
            pending = null
            result.error(ErrorCodes.UNSUPPORTED, error.message ?: "No folder picker available", null)
        }
    }

    /** Handles the picker result. Returns true when the request code was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) {
            return false
        }
        val result = pending ?: return true
        pending = null
        val treeUri = data?.data
        if (resultCode != Activity.RESULT_OK || treeUri == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            result.success(
                hashMapOf<String, Any?>(
                    "uri" to treeUri.toString(),
                    "name" to displayName(treeUri),
                ),
            )
        } catch (error: SecurityException) {
            result.error(ErrorCodes.ACCESS_LOST, error.message, null)
        } catch (error: Exception) {
            result.error(ErrorCodes.IO, error.message, null)
        }
        return true
    }

    /** True when the permission is still persisted and the folder can be read. */
    fun hasAccess(treeUriString: String): Boolean {
        val resolver = activity.contentResolver
        val persisted = resolver.persistedUriPermissions.any {
            it.uri.toString() == treeUriString && it.isReadPermission
        }
        if (!persisted) {
            return false
        }
        return try {
            val treeUri = Uri.parse(treeUriString)
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri,
                DocumentsContract.getTreeDocumentId(treeUri),
            )
            val cursor = resolver.query(
                children,
                arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
                null,
                null,
                null,
            )
            if (cursor == null) {
                false
            } else {
                cursor.close()
                true
            }
        } catch (error: Exception) {
            false
        }
    }

    /** Releases the persisted permission. Failures are ignored. */
    fun release(treeUriString: String) {
        try {
            activity.contentResolver.releasePersistableUriPermission(
                Uri.parse(treeUriString),
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (error: Exception) {
            // Already released or never granted: nothing to do.
        }
    }

    private fun displayName(treeUri: Uri): String {
        val documentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
        val cursor = activity.contentResolver.query(
            documentUri,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )
        cursor?.use {
            if (it.moveToFirst() && !it.isNull(0)) {
                return it.getString(0)
            }
        }
        return ""
    }
}
