import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:voicerecorder/services/google_drive.dart';

void main() {
  late Directory directory;
  late String audio;
  late List<http.Request> requests;
  late List<String?> invalidated;
  var token = 'token1';

  Future<Map<String, String>> authHeaders({String? invalidToken}) async {
    invalidated.add(invalidToken);
    if (invalidToken != null) token = 'token2';
    return {'Authorization': 'Bearer $token'};
  }

  DriveApi api(Future<http.Response> Function(http.Request request) handler) {
    return DriveApi(
      MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
      authHeaders,
    );
  }

  http.Response json(Object body, {int status = 200}) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('drive_test');
    audio = p.join(directory.path, 'a.m4a');
    await File(audio).writeAsBytes([1, 2, 3, 4]);
    requests = [];
    invalidated = [];
    token = 'token1';
  });

  tearDown(() => directory.delete(recursive: true));

  test('reutiliza la carpeta de la app si ya existe', () async {
    final drive = api(
      (request) async => json({
        'files': [
          {'id': 'folder1'},
        ],
      }),
    );

    expect(await drive.ensureFolder('Grabadora'), 'folder1');
    expect(requests.single.method, 'GET');
    expect(
      requests.single.url.queryParameters['q'],
      "mimeType='application/vnd.google-apps.folder' and name='Grabadora' "
      'and trashed=false',
    );
    expect(requests.single.headers['Authorization'], 'Bearer token1');
  });

  test('crea la carpeta si no existe', () async {
    final drive = api((request) async {
      if (request.method == 'GET') return json({'files': <Object>[]});
      return json({'id': 'new'});
    });

    expect(await drive.ensureFolder('Grabadora'), 'new');
    expect(requests.last.method, 'POST');
    expect(jsonDecode(requests.last.body), {
      'name': 'Grabadora',
      'mimeType': 'application/vnd.google-apps.folder',
    });
  });

  test('busca y crea las subcarpetas dentro de la de la app', () async {
    final drive = api((request) async {
      if (request.method == 'GET') return json({'files': <Object>[]});
      return json({'id': 'sub1'});
    });

    expect(await drive.ensureFolder('Clases', parentId: 'folder1'), 'sub1');
    expect(
      requests.first.url.queryParameters['q'],
      "mimeType='application/vnd.google-apps.folder' and name='Clases' "
      "and trashed=false and 'folder1' in parents",
    );
    expect(jsonDecode(requests.last.body), {
      'name': 'Clases',
      'mimeType': 'application/vnd.google-apps.folder',
      'parents': ['folder1'],
    });
  });

  test('sube un archivo nuevo con una subida reanudable', () async {
    final drive = api((request) async {
      if (request.method == 'POST') {
        return http.Response(
          '',
          200,
          headers: {'location': 'https://upload.example/session1'},
        );
      }
      return json({'id': 'file1'});
    });

    final id = await drive.upload(
      folderId: 'folder1',
      path: audio,
      name: 'Notas.m4a',
    );

    expect(id, 'file1');
    final start = requests.first;
    expect(start.url.path, '/upload/drive/v3/files');
    expect(start.url.queryParameters['uploadType'], 'resumable');
    expect(start.headers['X-Upload-Content-Type'], 'audio/mp4');
    expect(start.headers['X-Upload-Content-Length'], '4');
    expect(jsonDecode(start.body), {
      'name': 'Notas.m4a',
      'parents': ['folder1'],
      'mimeType': 'audio/mp4',
    });
    final put = requests.last;
    expect(put.method, 'PUT');
    expect(put.url.toString(), 'https://upload.example/session1');
    expect(put.bodyBytes, [1, 2, 3, 4]);
  });

  test('sustituye el contenido de un archivo existente', () async {
    final drive = api((request) async {
      if (request.method == 'PATCH') {
        return http.Response(
          '',
          200,
          headers: {'location': 'https://upload.example/session2'},
        );
      }
      return json({'id': 'file1'});
    });

    final id = await drive.upload(
      folderId: 'folder1',
      path: audio,
      name: 'Notas.m4a',
      fileId: 'file1',
    );

    expect(id, 'file1');
    expect(requests.first.method, 'PATCH');
    expect(requests.first.url.path, '/upload/drive/v3/files/file1');
    expect(jsonDecode(requests.first.body), {'name': 'Notas.m4a'});
  });

  test('si el archivo ya no existe en Drive, lo crea de nuevo', () async {
    final drive = api((request) async {
      switch (request.method) {
        case 'PATCH':
          return json({
            'error': {'message': 'File not found'},
          }, status: 404);
        case 'POST':
          return http.Response(
            '',
            200,
            headers: {'location': 'https://upload.example/s'},
          );
        default:
          return json({'id': 'file2'});
      }
    });

    final id = await drive.upload(
      folderId: 'folder1',
      path: audio,
      name: 'Notas.m4a',
      fileId: 'gone',
    );

    expect(id, 'file2');
    expect(requests.map((r) => r.method), ['PATCH', 'POST', 'PUT']);
  });

  test('renueva el token caducado y repite la petición', () async {
    final drive = api((request) async {
      if (request.headers['Authorization'] == 'Bearer token1') {
        return http.Response('', 401);
      }
      return json({'id': 'file1'});
    });

    await drive.rename(fileId: 'file1', name: 'Nuevo.m4a');

    expect(invalidated, [null, 'token1']);
    expect(requests, hasLength(2));
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, '/drive/v3/files/file1');
    expect(jsonDecode(requests.last.body), {'name': 'Nuevo.m4a'});
  });

  test('traduce los errores de la API', () async {
    final drive = api(
      (request) async => json({
        'error': {'message': 'Storage quota exceeded'},
      }, status: 403),
    );

    await expectLater(
      drive.rename(fileId: 'file1', name: 'x'),
      throwsA(
        isA<DriveException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'Storage quota exceeded'),
      ),
    );
  });

  test('pide volver a conectar si el token sigue sin valer', () async {
    final drive = api((request) async => http.Response('', 401));

    await expectLater(
      drive.ensureFolder('Grabadora'),
      throwsA(isA<DriveAuthException>()),
    );
  });

  test('lista los archivos de una carpeta, página a página', () async {
    final drive = api((request) async {
      if (request.url.queryParameters['pageToken'] == null) {
        return json({
          'nextPageToken': 'p2',
          'files': [
            {
              'id': 'f1',
              'name': 'Idea.m4a',
              'mimeType': 'audio/mp4',
              'size': '1234',
              'modifiedTime': '2026-03-02T09:15:00.000Z',
            },
          ],
        });
      }
      return json({
        'files': [
          {
            'id': 'd1',
            'name': 'Clases',
            'mimeType': 'application/vnd.google-apps.folder',
          },
        ],
      });
    });

    final entries = await drive.list('folder1');

    expect(entries.map((e) => (e.ref, e.name, e.isDirectory, e.size)), [
      ('f1', 'Idea.m4a', false, 1234),
      ('d1', 'Clases', true, null),
    ]);
    expect(entries.first.modified, DateTime.utc(2026, 3, 2, 9, 15).toLocal());
    expect(
      requests.first.url.queryParameters['q'],
      "'folder1' in parents and trashed=false",
    );
    expect(requests.last.url.queryParameters['pageToken'], 'p2');
  });

  test('descarga un archivo, renovando el token si ha caducado', () async {
    final drive = api((request) async {
      if (request.headers['Authorization'] == 'Bearer token1') {
        return http.Response('', 401);
      }
      return http.Response.bytes([5, 6, 7], 200);
    });
    final destination = p.join(directory.path, 'descarga.m4a');

    await drive.download(fileId: 'f1', destination: destination);

    expect(File(destination).readAsBytesSync(), [5, 6, 7]);
    expect(requests.last.url.path, '/drive/v3/files/f1');
    expect(requests.last.url.queryParameters['alt'], 'media');
    expect(invalidated.last, 'token1');
  });

  test('si la descarga falla, lanza el error de Drive', () async {
    final drive = api(
      (request) async => json({
        'error': {'message': 'File not found'},
      }, status: 404),
    );

    await expectLater(
      drive.download(
        fileId: 'f1',
        destination: p.join(directory.path, 'x.m4a'),
      ),
      throwsA(
        isA<DriveException>().having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('borrar manda a la papelera y no falla si ya no existe', () async {
    var status = 200;
    final drive = api((request) async => json({'id': 'f1'}, status: status));

    await drive.trash('f1');
    expect(requests.last.method, 'PATCH');
    expect(jsonDecode(requests.last.body), {'trashed': true});

    status = 404;
    await drive.trash('f1');
  });
}
