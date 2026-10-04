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
import java.io.IOException
import java.io.OutputStream

/**
 * Copia archivos a una carpeta elegida por el usuario con el selector del
 * sistema (Storage Access Framework). El permiso sobre la carpeta se conserva
 * entre reinicios.
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
                val ref = call.argument<String>("ref")
                runner.run(result) { writeFile(Uri.parse(folder), ref?.let(Uri::parse), source, name) }
            }
            "renameFile" -> {
                val ref = call.argument<String>("ref") ?: return badArgs(result)
                val name = call.argument<String>("name") ?: return badArgs(result)
                runner.run(result) { renameFile(Uri.parse(ref), name) }
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

    private fun writeFile(tree: Uri, ref: Uri?, source: String, name: String): String {
        val resolver = context.contentResolver
        val existing = ref?.takeIf { exists(it) }
        val target = existing
            ?: DocumentsContract.createDocument(resolver, folderDocument(tree), mimeTypeOf(name), name)
            ?: throw IOException("No se pudo crear el archivo en la carpeta")
        openForWriting(target).use { output ->
            FileInputStream(source).use { input -> input.copyTo(output) }
        }
        return target.toString()
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
