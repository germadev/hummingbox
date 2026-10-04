import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/recording_options.dart';
import 'settings_store.dart';

/// Hay que volver a conectar la cuenta de Google (sesión cerrada, permiso
/// retirado…).
class DriveAuthException implements Exception {
  const DriveAuthException([
    this.message = 'Vuelve a conectar tu cuenta de Google Drive',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Error devuelto por la API de Google Drive.
class DriveException implements Exception {
  const DriveException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'Google Drive ($statusCode): $message';
}

/// Copias de las grabaciones en Google Drive. Abstraído para poder
/// sustituirlo en los tests.
abstract interface class DriveService {
  /// Indica si la app tiene configurado el acceso a Google en esta
  /// plataforma (ver README → «Google Drive»).
  bool get isAvailable;

  /// Inicia sesión, pide permiso para crear archivos en Drive y prepara la
  /// carpeta de las grabaciones. Devuelve `null` si el usuario lo cancela.
  Future<DriveSettings?> connect();

  /// Cierra la sesión y retira el permiso.
  Future<void> disconnect();

  /// Sube [path] a la carpeta [folderId] (o a su subcarpeta [subfolder],
  /// que se crea si no existe) con el nombre [name]. Si [fileId] sigue
  /// existiendo, sustituye su contenido. Devuelve el id del archivo.
  Future<String> upload({
    required String folderId,
    required String path,
    required String name,
    String subfolder = '',
    String? fileId,
  });

  /// Cambia el nombre del archivo [fileId]. Lanza [DriveException] con código
  /// 404 si ya no existe.
  Future<void> rename({required String fileId, required String name});
}

/// Implementación con Google Sign-In y la API REST de Drive.
///
/// Usa el permiso `drive.file`, que solo da acceso a los archivos que crea
/// la propia app.
class GoogleDriveService implements DriveService {
  GoogleDriveService({
    required this.iosClientId,
    required this.serverClientId,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// ID de cliente OAuth de iOS.
  final String iosClientId;

  /// ID de cliente OAuth «web», necesario en Android.
  final String serverClientId;

  final http.Client _http;

  static const folderName = 'Grabadora';
  static const scopes = ['https://www.googleapis.com/auth/drive.file'];

  late final DriveApi _api = DriveApi(_http, _authHeaders);
  Future<void>? _initialization;

  /// Ids de las subcarpetas ya encontradas o creadas, por carpeta y nombre.
  final _subfolders = <(String, String), Future<String>>{};

  @override
  bool get isAvailable {
    if (Platform.isIOS) return iosClientId.isNotEmpty;
    if (Platform.isAndroid) return serverClientId.isNotEmpty;
    return false;
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? iosClientId : null,
      serverClientId: Platform.isAndroid ? serverClientId : null,
    );
  }

  @override
  Future<DriveSettings?> connect() async {
    if (!isAvailable) {
      throw const DriveAuthException(
        'Esta versión de la app no tiene configurado el acceso a Google',
      );
    }
    await _ensureInitialized();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
      await account.authorizationClient.authorizeScopes(scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final folderId = await _api.ensureFolder(folderName);
    return DriveSettings(email: account.email, folderId: folderId);
  }

  @override
  Future<void> disconnect() async {
    await _ensureInitialized();
    try {
      await GoogleSignIn.instance.disconnect();
    } on GoogleSignInException {
      await GoogleSignIn.instance.signOut();
    }
  }

  /// Cabeceras con un token válido, obtenido sin mostrar nada al usuario.
  Future<Map<String, String>> _authHeaders({String? invalidToken}) async {
    await _ensureInitialized();
    final client = GoogleSignIn.instance.authorizationClient;
    if (invalidToken != null) {
      await client.clearAuthorizationToken(accessToken: invalidToken);
    }
    final Map<String, String>? headers;
    try {
      headers = await client.authorizationHeaders(scopes);
    } on GoogleSignInException {
      throw const DriveAuthException();
    }
    if (headers == null) throw const DriveAuthException();
    return headers;
  }

  @override
  Future<String> upload({
    required String folderId,
    required String path,
    required String name,
    String subfolder = '',
    String? fileId,
  }) async {
    var parent = folderId;
    if (subfolder.isNotEmpty) {
      final key = (folderId, subfolder);
      final lookup = _subfolders[key] ??= _api.ensureFolder(
        subfolder,
        parentId: folderId,
      );
      try {
        parent = await lookup;
      } catch (_) {
        // Se vuelve a intentar en la siguiente subida.
        _subfolders.remove(key);
        rethrow;
      }
    }
    return _api.upload(
      folderId: parent,
      path: path,
      name: name,
      fileId: fileId,
    );
  }

  @override
  Future<void> rename({required String fileId, required String name}) =>
      _api.rename(fileId: fileId, name: name);
}

/// Llamadas a la API REST de Google Drive v3.
class DriveApi {
  DriveApi(this._client, this._authHeaders);

  final http.Client _client;

  /// Devuelve las cabeceras de autorización. Si se indica [invalidToken], ese
  /// token ha caducado y hay que obtener otro.
  final Future<Map<String, String>> Function({String? invalidToken})
  _authHeaders;

  static final _files = Uri.parse('https://www.googleapis.com/drive/v3/files');
  static final _uploads = Uri.parse(
    'https://www.googleapis.com/upload/drive/v3/files',
  );
  static const folderMimeType = 'application/vnd.google-apps.folder';
  static const _jsonType = 'application/json; charset=UTF-8';

  /// Devuelve el id de la carpeta [name] creada por la app (dentro de
  /// [parentId], si se indica), creándola si no existe.
  Future<String> ensureFolder(String name, {String? parentId}) async {
    String escape(String value) =>
        value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final conditions = [
      "mimeType='$folderMimeType'",
      "name='${escape(name)}'",
      'trashed=false',
      if (parentId != null) "'${escape(parentId)}' in parents",
    ];
    final found = await _send(
      (headers) => _client.get(
        _files.replace(
          queryParameters: {
            'q': conditions.join(' and '),
            'fields': 'files(id)',
            'spaces': 'drive',
          },
        ),
        headers: headers,
      ),
    );
    final files = _json(found)['files'];
    if (files is List && files.isNotEmpty) {
      return (files.first as Map<String, dynamic>)['id'] as String;
    }

    final created = await _send(
      (headers) => _client.post(
        _files.replace(queryParameters: {'fields': 'id'}),
        headers: {...headers, 'Content-Type': _jsonType},
        body: jsonEncode({
          'name': name,
          'mimeType': folderMimeType,
          if (parentId != null) 'parents': [parentId],
        }),
      ),
    );
    return _json(created)['id'] as String;
  }

  Future<String> upload({
    required String folderId,
    required String path,
    required String name,
    String? fileId,
  }) async {
    if (fileId != null) {
      try {
        return await _upload(path, {'name': name}, fileId: fileId);
      } on DriveException catch (e) {
        // El archivo se borró de Drive: se sube de nuevo.
        if (e.statusCode != 404) rethrow;
      }
    }
    return _upload(path, {
      'name': name,
      'parents': [folderId],
      'mimeType': _mimeTypeOf(path),
    });
  }

  Future<void> rename({required String fileId, required String name}) async {
    await _send(
      (headers) => _client.patch(
        _files.replace(
          path: '${_files.path}/$fileId',
          queryParameters: {'fields': 'id'},
        ),
        headers: {...headers, 'Content-Type': _jsonType},
        body: jsonEncode({'name': name}),
      ),
    );
  }

  /// Subida reanudable: primero se envían los metadatos y luego el audio, sin
  /// cargarlo entero en memoria.
  Future<String> _upload(
    String path,
    Map<String, Object> metadata, {
    String? fileId,
  }) async {
    final length = await File(path).length();
    final session = await _send((headers) async {
      final request =
          http.Request(
              fileId == null ? 'POST' : 'PATCH',
              _uploads.replace(
                path: fileId == null
                    ? _uploads.path
                    : '${_uploads.path}/$fileId',
                queryParameters: {'uploadType': 'resumable', 'fields': 'id'},
              ),
            )
            ..headers.addAll({
              ...headers,
              'Content-Type': _jsonType,
              'X-Upload-Content-Type': _mimeTypeOf(path),
              'X-Upload-Content-Length': '$length',
            })
            ..body = jsonEncode(metadata);
      return http.Response.fromStream(await _client.send(request));
    });
    final location = session.headers['location'];
    if (location == null) {
      throw DriveException(
        session.statusCode,
        'no se recibió la dirección de subida',
      );
    }

    final request = http.StreamedRequest('PUT', Uri.parse(location))
      ..contentLength = length
      ..headers['Content-Type'] = _mimeTypeOf(path);
    final responseFuture = _client.send(request);
    await request.sink.addStream(File(path).openRead());
    await request.sink.close();
    final response = await http.Response.fromStream(await responseFuture);
    _check(response);
    return _json(response)['id'] as String;
  }

  static String _mimeTypeOf(String path) =>
      (RecordingFormat.fromPath(path) ?? RecordingFormat.aac).mimeType;

  /// Hace la petición y, si el token ha caducado, la repite una vez con uno
  /// nuevo.
  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    var headers = await _authHeaders();
    var response = await request(headers);
    if (response.statusCode == 401) {
      final token = headers['Authorization']?.replaceFirst('Bearer ', '');
      headers = await _authHeaders(invalidToken: token);
      response = await request(headers);
      if (response.statusCode == 401) throw const DriveAuthException();
    }
    _check(response);
    return response;
  }

  static void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = response.reasonPhrase ?? 'error desconocido';
    try {
      final error = _json(response)['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        message = error['message'] as String;
      }
    } on FormatException {
      // Respuesta sin JSON: se usa el texto del estado.
    }
    throw DriveException(response.statusCode, message);
  }

  static Map<String, dynamic> _json(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta inesperada de Google Drive');
    }
    return decoded;
  }
}
