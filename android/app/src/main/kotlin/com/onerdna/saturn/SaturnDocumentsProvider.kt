package com.onerdna.saturn

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider
import java.io.File
import java.io.FileNotFoundException

class SaturnDocumentsProvider : DocumentsProvider() {

    private val rootProjection = arrayOf(
        DocumentsContract.Root.COLUMN_ROOT_ID,
        DocumentsContract.Root.COLUMN_DOCUMENT_ID,
        DocumentsContract.Root.COLUMN_TITLE,
        DocumentsContract.Root.COLUMN_FLAGS,
        DocumentsContract.Root.COLUMN_MIME_TYPES,
        DocumentsContract.Root.COLUMN_ICON
    )

    private val docProjection = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_FLAGS,
        DocumentsContract.Document.COLUMN_SIZE
    )

    override fun onCreate(): Boolean {
        return true
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: rootProjection)
        val ctx = context ?: return result

        try {
            val appDir = ctx.getExternalFilesDir(null) ?: ctx.filesDir
            if (!appDir.exists()) {
                appDir.mkdirs()
            }

            val iconRes = if (ctx.applicationInfo.icon != 0) ctx.applicationInfo.icon else android.R.mipmap.sym_def_app_icon

            result.newRow().apply {
                add(DocumentsContract.Root.COLUMN_ROOT_ID, "saturn_root")
                add(DocumentsContract.Root.COLUMN_DOCUMENT_ID, appDir.absolutePath)
                add(DocumentsContract.Root.COLUMN_TITLE, "Saturn")
                add(
                    DocumentsContract.Root.COLUMN_FLAGS,
                    DocumentsContract.Root.FLAG_SUPPORTS_CREATE or DocumentsContract.Root.FLAG_SUPPORTS_SEARCH
                )
                add(DocumentsContract.Root.COLUMN_MIME_TYPES, "*/*")
                add(DocumentsContract.Root.COLUMN_ICON, iconRes)
            }
        } catch (_: Exception) {}

        return result
    }

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: docProjection)
        val file = File(documentId)
        if (file.exists()) {
            appendFile(result, file)
        }
        return result
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val result = MatrixCursor(projection ?: docProjection)
        val parent = File(parentDocumentId)
        if (parent.exists() && parent.isDirectory) {
            parent.listFiles()?.forEach { file ->
                appendFile(result, file)
            }
        }
        return result
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        val file = File(documentId)
        val accessMode = ParcelFileDescriptor.parseMode(mode)
        return ParcelFileDescriptor.open(file, accessMode)
    }

    override fun createDocument(
        parentDocumentId: String,
        mimeType: String,
        displayName: String
    ): String {
        val parent = File(parentDocumentId)
        if (!parent.exists()) {
            parent.mkdirs()
        }
        val file = File(parent, displayName)
        if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
            file.mkdirs()
        } else {
            file.createNewFile()
        }
        return file.absolutePath
    }

    override fun deleteDocument(documentId: String) {
        val file = File(documentId)
        if (!file.deleteRecursively()) {
            throw FileNotFoundException("Failed to delete $documentId")
        }
    }

    private fun appendFile(result: MatrixCursor, file: File) {
        var flags = 0
        if (file.isDirectory) {
            if (file.canWrite()) flags = flags or DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE
        } else if (file.canWrite()) {
            flags = flags or DocumentsContract.Document.FLAG_SUPPORTS_WRITE or DocumentsContract.Document.FLAG_SUPPORTS_DELETE
        }

        val mime = if (file.isDirectory) DocumentsContract.Document.MIME_TYPE_DIR else "application/octet-stream"

        result.newRow().apply {
            add(DocumentsContract.Document.COLUMN_DOCUMENT_ID, file.absolutePath)
            add(DocumentsContract.Document.COLUMN_DISPLAY_NAME, file.name)
            add(DocumentsContract.Document.COLUMN_SIZE, file.length())
            add(DocumentsContract.Document.COLUMN_MIME_TYPE, mime)
            add(DocumentsContract.Document.COLUMN_LAST_MODIFIED, file.lastModified())
            add(DocumentsContract.Document.COLUMN_FLAGS, flags)
        }
    }
}
