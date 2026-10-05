package es.germade.voicerecorder_native

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream

/**
 * Lee, escribe y borra archivos en una carpeta elegida por el usuario con el
 * selector del sistema (Storage Access Framework) y en sus subcarpetas. El
 * permiso sobre la carpeta se conserva entre reinicios.
 */
internal class FolderAccess(private val context: Context) :
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private val runner = BackgroundRunner()
    private var binding: ActivityPluginBinding? = null
    private var pendingPick: MethodChannel.Result? = null

    fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    fun detach() {
        binding?.removeActivityResultListener(this)
        binding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> pickFolder(result)
            "writeFile" -> {
                val folder = call.argument<String>("folder") ?: return badArgs(result)
                val source = call.argument<String>("source") ?: return badArgs(result)
                val name = call.argument<String>("name") ?: return badArgs(result)
                val subfolder = call.argument<String>("subfolder") ?: ""
                val ref = call.argument<String>("ref")
                runner.run(result) {
                    writeFile(Uri.parse(folder), subfolder, ref?.let(Uri::parse), source, name)
                }
            }
            "listFiles" -> {
                val folder = call.argument<String>("folder") ?: return badArgs(result)
                val subfolder = call.argument<String>("subfolder") ?: ""
                runner.run(result) { listFiles(Uri.parse(folder), subfolder) }
            }
            "readFile" -> {
                val ref = call.argument<String>("ref") ?: return badArgs(result)
                val destination = call.argument<String>("destination") ?: return badArgs(result)
                runner.run(result) {
                    readFile(Uri.parse(ref), destination)
                    null
                }
            }
            "createFolder" -> {
                val folder = call.argument<String>("folder") ?: return badArgs(result)
                val name = call.argument<String>("name") ?: return badArgs(result)
                runner.run(result) {
                    subfolderDocument(Uri.parse(folder), name, create = true)
                    null
                }
            }
            "renameFile" -> {
                val ref = call.argument<String>("ref") ?: return badArgs(result)
                val name = call.argument<String>("name") ?: return badArgs(result)
                runner.run(result) { renameFile(Uri.parse(ref), name) }
            }
            "deleteFile" -> {
                val ref = call.argument<String>("ref") ?: return badArgs(result)
                runner.run(result) {
                    deleteFile(Uri.parse(ref))
                    null
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun badArgs(result: MethodChannel.Result) =
        result.error("bad_args", "Faltan argumentos", null)

    private fun pickFolder(result: MethodChannel.Result) {
        val activity = binding?.activity
        if (activity == null) {
            result.error("no_activity", "No hay ninguna pantalla abierta", null)
            return
        }
        if (pendingPick != null) {
            result.error("busy", "Ya se está eligiendo una carpeta", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        pendingPick = result
        try {
            activity.startActivityForResult(intent, REQUEST_PICK_FOLDER)
        } catch (e: ActivityNotFoundException) {
            pendingPick = null
            result.error("unavailable", "El dispositivo no tiene selector de carpetas", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_FOLDER) return false
        val result = pendingPick ?: return true
        pendingPick = null

        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        try {
            val resolver = context.contentResolver
            resolver.takePersistableUriPermission(tree, PERMISSION_FLAGS)
            // Solo se usa una carpeta: se liberan los permisos de las anteriores.
            resolver.persistedUriPermissions
                .filter { it.uri != tree }
                .forEach { runCatching { resolver.releasePersistableUriPermission(it.uri, PERMISSION_FLAGS) } }
            val name = displayName(folderDocument(tree)) ?: tree.lastPathSegment ?: "Carpeta"
            result.success(mapOf("id" to tree.toString(), "name" to name))
        } catch (e: Exception) {
            result.error("failed", e.message ?: e.javaClass.simpleName, null)
        }
        return true
    }

    private fun writeFile(tree: Uri, subfolder: String, ref: Uri?, source: String, name: String): String {
        val resolver = context.contentResolver
        val existing = ref?.takeIf { exists(it) }
        val target = existing
            ?: DocumentsContract.createDocument(
                resolver,
                if (subfolder.isEmpty()) folderDocument(tree) else subfolderDocument(tree, subfolder, create = true)!!,
                mimeTypeOf(name),
                name,
            )
            ?: throw IOException("No se pudo crear el archivo en la carpeta")
        openForWriting(target).use { output ->
            FileInputStream(source).use { input -> input.copyTo(output) }
        }
        return target.toString()
    }

    /**
     * Archivos y subcarpetas de la carpeta o de su subcarpeta [subfolder]. Si
     * la subcarpeta no existe, la lista está vacía.
     */
    private fun listFiles(tree: Uri, subfolder: String): List<Map<String, Any?>> {
        val parent = if (subfolder.isEmpty()) {
            folderDocument(tree)
        } else {
            subfolderDocument(tree, subfolder, create = false) ?: return emptyList()
        }
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree, DocumentsContract.getDocumentId(parent),
        )
        val files = mutableListOf<Map<String, Any?>>()
        val cursor = context.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
            null, null, null,
        ) ?: throw IOException("No se pudo leer la carpeta")
        cursor.use {
            while (it.moveToNext()) {
                val id = it.getString(0) ?: continue
                val name = it.getString(1) ?: continue
                files += mapOf(
                    "ref" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                    "name" to name,
                    "isDirectory" to (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR),
                    "size" to if (it.isNull(3)) null else it.getLong(3),
                    "modified" to if (it.isNull(4)) null else it.getLong(4),
                )
            }
        }
        return files
    }

    private fun readFile(ref: Uri, destination: String) {
        val input = context.contentResolver.openInputStream(ref)
            ?: throw IOException("No se pudo leer el archivo")
        input.use { FileOutputStream(destination).use { output -> input.copyTo(output) } }
    }

    /**
     * Documento de la subcarpeta [name] de la carpeta. Si no existe, la crea
     * si [create] o devuelve `null`.
     */
    private fun subfolderDocument(tree: Uri, name: String, create: Boolean): Uri? {
        val parent = folderDocument(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree, DocumentsContract.getDocumentId(parent),
        )
        context.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null, null, null,
        )?.use {
            while (it.moveToNext()) {
                if (it.getString(1) == name &&
                    it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR
                ) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0))
                }
            }
        }
        if (!create) return null
        return DocumentsContract.createDocument(
            context.contentResolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, name,
        ) ?: throw IOException("No se pudo crear la carpeta")
    }

    /** Abre el documento truncándolo; algunos proveedores solo admiten "w". */
    private fun openForWriting(uri: Uri): OutputStream {
        val resolver = context.contentResolver
        val truncating = try {
            resolver.openOutputStream(uri, "wt")
        } catch (e: FileNotFoundException) {
            null
        } catch (e: IllegalArgumentException) {
            null
        }
        val stream = truncating ?: resolver.openOutputStream(uri, "w")
        return stream ?: throw IOException("No se pudo escribir en la carpeta")
    }

    private fun renameFile(ref: Uri, name: String): String = try {
        DocumentsContract.renameDocument(context.contentResolver, ref, name)?.toString() ?: ref.toString()
    } catch (e: UnsupportedOperationException) {
        // El proveedor no permite renombrar: se conserva el nombre anterior.
        ref.toString()
    }

    /** Borra el documento [ref]. Si ya no existe, no hace nada. */
    private fun deleteFile(ref: Uri) {
        if (!exists(ref)) return
        try {
            if (!DocumentsContract.deleteDocument(context.contentResolver, ref)) {
                throw IOException("No se pudo borrar el archivo")
            }
        } catch (e: FileNotFoundException) {
            // Se borró entretanto.
        }
    }

    private fun exists(uri: Uri): Boolean = try {
        context.contentResolver.query(
            uri, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null,
        )?.use { it.moveToFirst() } ?: false
    } catch (e: Exception) {
        false
    }

    private fun displayName(uri: Uri): String? = try {
        context.contentResolver.query(
            uri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }
    } catch (e: Exception) {
        null
    }

    private fun folderDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    /**
     * Tipo MIME según la extensión. Si coincide con el que Android asocia a la
     * extensión, el proveedor respeta el nombre tal cual.
     */
    private fun mimeTypeOf(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    private companion object {
        const val REQUEST_PICK_FOLDER = 0x5646
        const val PERMISSION_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }
}
