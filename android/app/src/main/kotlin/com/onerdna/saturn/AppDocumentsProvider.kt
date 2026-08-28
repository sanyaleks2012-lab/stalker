package com.onerdna.saturn

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider
import java.io.File
import java.io.FileNotFoundException

class AppDocumentsProvider : DocumentsProvider() {

    private val defaultRootProjection: Array<String> = arrayOf(
        DocumentsContract.Root.COLUMN_ROOT_ID,
        DocumentsContract.Root.COLUMN_MIME_TYPES,
        DocumentsContract.Root.COLUMN_FLAGS,
        DocumentsContract.Root.COLUMN_ICON,
        DocumentsContract.Root.COLUMN_TITLE,
        DocumentsContract.Root.COLUMN_DOCUMENT_ID
    )

    private val defaultDocumentProjection: Array<String> = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_FLAGS,
        DocumentsContract.Document.COLUMN_SIZE
    )

    override fun onCreate(): Boolean = true

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: defaultRootProjection)
        val context = context ?: return result
        val appDir = context.filesDir

        result.newRow().apply {
            add(DocumentsContract.Root.COLUMN_ROOT_ID, "saturn_root")
            add(DocumentsContract.Root.COLUMN_DOCUMENT_ID, getDocIdForFile(appDir))
            add(DocumentsContract.Root.COLUMN_TITLE, "Saturn")
            add(
                DocumentsContract.Root.COLUMN_FLAGS,
                DocumentsContract.Root.FLAG_SUPPORTS_CREATE or DocumentsContract.Root.FLAG_SUPPORTS_SEARCH
            )
            add(DocumentsContract.Root.COLUMN_MIME_TYPES, "*/*")
            add(DocumentsContract.Root.COLUMN_ICON, context.applicationInfo.icon)
        }
        return result
    }

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor {
        val result = MatrixCursor(projection ?: defaultDocumentProjection)
        includeFile(result, documentId, null)
        return result
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val result = MatrixCursor(projection ?: defaultDocumentProjection)
        val parent = getFileForDocId(parentDocumentId)
        parent.listFiles()?.forEach { file ->
            includeFile(result, null, file)
        }
        return result
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        val file = getFileForDocId(documentId)
        val accessMode = ParcelFileDescriptor.parseMode(mode)
        return ParcelFileDescriptor.open(file, accessMode)
    }

    override fun createDocument(
        parentDocumentId: String,
        mimeType: String,
        displayName: String
    ): String {
        val parent = getFileForDocId(parentDocumentId)
        val file = File(parent, displayName)
        if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
            if (!file.mkdirs()) {
                throw FileNotFoundException("Failed to create directory: ${file.absolutePath}")
            }
        } else {
            if (!file.createNewFile()) {
                throw FileNotFoundException("Failed to create file: ${file.absolutePath}")
            }
        }
        return getDocIdForFile(file)
    }

    override fun deleteDocument(documentId: String) {
        val file = getFileForDocId(documentId)
        if (!file.deleteRecursively()) {
            throw FileNotFoundException("Failed to delete $documentId")
        }
    }

    private fun includeFile(result: MatrixCursor, docId: String?, file: File?) {
        val targetFile = file ?: getFileForDocId(docId!!)
        val id = docId ?: getDocIdForFile(targetFile)

        var flags = 0
        if (targetFile.isDirectory) {
            if (targetFile.canWrite()) {
                flags = flags or DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE
            }
        } else if (targetFile.canWrite()) {
            flags = flags or DocumentsContract.Document.FLAG_SUPPORTS_WRITE or DocumentsContract.Document.FLAG_SUPPORTS_DELETE
        }

        val mimeType = if (targetFile.isDirectory) {
            DocumentsContract.Document.MIME_TYPE_DIR
        } else {
            "application/octet-stream"
        }

        result.newRow().apply {
            add(DocumentsContract.Document.COLUMN_DOCUMENT_ID, id)
            add(DocumentsContract.Document.COLUMN_DISPLAY_NAME, targetFile.name)
            add(DocumentsContract.Document.COLUMN_SIZE, targetFile.length())
            add(DocumentsContract.Document.COLUMN_MIME_TYPE, mimeType)
            add(DocumentsContract.Document.COLUMN_LAST_MODIFIED, targetFile.lastModified())
            add(DocumentsContract.Document.COLUMN_FLAGS, flags)
        }
    }

    private fun getDocIdForFile(file: File): String {
        val path = file.absolutePath
        val rootPath = context!!.filesDir.absolutePath
        return if (path.startsWith(rootPath)) {
            "root" + path.substring(rootPath.length)
        } else {
            path
        }
    }

    private fun getFileForDocId(docId: String): File {
        val rootDir = context!!.filesDir
        return if (docId == "root") {
            rootDir
        } else if (docId.startsWith("root/")) {
            File(rootDir, docId.substring(5))
        } else {
            File(docId)
        }
    }
}
