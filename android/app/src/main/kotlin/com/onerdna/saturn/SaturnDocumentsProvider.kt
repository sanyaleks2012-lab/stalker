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

    companion object {
        private const val ROOT_ID = "saturn_data_root"

        private val DEFAULT_ROOT_PROJECTION = arrayOf(
            DocumentsContract.Root.COLUMN_ROOT_ID,
            DocumentsContract.Root.COLUMN_FLAGS,
            DocumentsContract.Root.COLUMN_TITLE,
            DocumentsContract.Root.COLUMN_SUMMARY,
            DocumentsContract.Root.COLUMN_DOCUMENT_ID,
            DocumentsContract.Root.COLUMN_MIME_TYPES,
            DocumentsContract.Root.COLUMN_ICON
        )

        private val DEFAULT_DOCUMENT_PROJECTION = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_FLAGS,
            DocumentsContract.Document.COLUMN_SIZE
        )
    }

    override fun onCreate(): Boolean = true

    // Термукс-подход: явно берем внутренний ctx.filesDir (/data/data/com.onerdna.saturn/files)
    private fun getBaseDir(): File {
        val ctx = context ?: throw IllegalStateException("Context is null")
        val dir = ctx.filesDir 
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    private fun getFileForDocId(docId: String): File {
        val base = getBaseDir()
        if (docId == ROOT_ID || docId.isEmpty()) {
            return base
        }
        val target = File(base, docId)
        // Защита от Directory Traversal (../)
        if (!target.canonicalPath.startsWith(base.canonicalPath)) {
            throw SecurityException("Access denied: path outside sandbox")
        }
        return target
    }

    private fun getDocIdForFile(file: File): String {
        val base = getBaseDir()
        if (file.canonicalPath == base.canonicalPath) {
            return ROOT_ID
        }
        return file.canonicalPath.substring(base.canonicalPath.length + 1)
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_ROOT_PROJECTION)
        val ctx = context ?: return result

        val iconRes = if (ctx.applicationInfo.icon != 0) ctx.applicationInfo.icon else android.R.mipmap.sym_def_app_icon

        result.newRow().apply {
            add(DocumentsContract.Root.COLUMN_ROOT_ID, ROOT_ID)
            add(DocumentsContract.Root.COLUMN_DOCUMENT_ID, ROOT_ID)
            add(DocumentsContract.Root.COLUMN_TITLE, "Saturn")
            add(DocumentsContract.Root.COLUMN_SUMMARY, "/data/data/com.onerdna.saturn/files")
            add(
                DocumentsContract.Root.COLUMN_FLAGS,
                DocumentsContract.Root.FLAG_SUPPORTS_CREATE or
                DocumentsContract.Root.FLAG_SUPPORTS_SEARCH or
                DocumentsContract.Root.FLAG_LOCAL_ONLY
            )
            add(DocumentsContract.Root.COLUMN_MIME_TYPES, "*/*")
            add(DocumentsContract.Root.COLUMN_ICON, iconRes)
        }
        return result
    }

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val file = getFileForDocId(documentId)
        if (file.exists()) {
            appendFile(result, documentId, file)
        }
        return result
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val result = MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
        val parent = getFileForDocId(parentDocumentId)
        if (parent.exists() && parent.isDirectory) {
            parent.listFiles()?.forEach { file ->
                appendFile(result, getDocIdForFile(file), file)
            }
        }
        return result
    }

    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean {
        return documentId.startsWith(parentDocumentId)
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        val file = getFileForDocId(documentId)
        if (!file.exists()) throw FileNotFoundException("File missing: ${file.absolutePath}")
        
        val accessMode = ParcelFileDescriptor.parseMode(mode)
        return ParcelFileDescriptor.open(file, accessMode)
    }

    override fun createDocument(
        parentDocumentId: String,
        mimeType: String,
        displayName: String
    ): String {
        val parent = getFileForDocId(parentDocumentId)
        if (!parent.exists()) {
            parent.mkdirs()
        }
        val file = File(parent, displayName)
        if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
            file.mkdirs()
        } else {
            file.createNewFile()
        }
        return getDocIdForFile(file)
    }

    override fun deleteDocument(documentId: String) {
        val file = getFileForDocId(documentId)
        if (!file.deleteRecursively()) {
            throw FileNotFoundException("Failed to delete $documentId")
        }
    }

    override fun renameDocument(documentId: String, displayName: String): String? {
        val file = getFileForDocId(documentId)
        val target = File(file.parentFile, displayName)
        if (file.renameTo(target)) {
            return getDocIdForFile(target)
        }
        throw FileNotFoundException("Failed to rename $documentId")
    }

    private fun appendFile(result: MatrixCursor, docId: String, file: File) {
        var flags = DocumentsContract.Document.FLAG_SUPPORTS_DELETE or
                    DocumentsContract.Document.FLAG_SUPPORTS_RENAME

        if (file.isDirectory) {
            flags = flags or DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE
        } else {
            flags = flags or DocumentsContract.Document.FLAG_SUPPORTS_WRITE
        }

        val mime = if (file.isDirectory) DocumentsContract.Document.MIME_TYPE_DIR else "application/octet-stream"

        result.newRow().apply {
            add(DocumentsContract.Document.COLUMN_DOCUMENT_ID, docId)
            add(DocumentsContract.Document.COLUMN_DISPLAY_NAME, file.name)
            add(DocumentsContract.Document.COLUMN_SIZE, file.length())
            add(DocumentsContract.Document.COLUMN_MIME_TYPE, mime)
            add(DocumentsContract.Document.COLUMN_LAST_MODIFIED, file.lastModified())
            add(DocumentsContract.Document.COLUMN_FLAGS, flags)
        }
    }
}
