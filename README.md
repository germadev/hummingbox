# Grabadora de voz

Aplicación móvil (Android e iOS) hecha con Flutter para grabar, escuchar y
gestionar notas de voz.

<p>
  <img src="docs/lista.png" width="200" alt="Lista de grabaciones con la onda de cada una y una en reproducción">
  <img src="docs/preparado.png" width="200" alt="Panel de grabación desplegado, listo para grabar">
  <img src="docs/grabando.png" width="200" alt="Pantalla durante una grabación">
</p>
<p>
  <img src="docs/editor.png" width="200" alt="Modo de edición con la selección recortada, el volumen y los fundidos">
  <img src="docs/opciones.png" width="200" alt="Opciones con una carpeta y Google Drive conectados">
</p>

## Funciones

- **Grabar** con un solo toque, con **pausa/reanudar** y cronómetro.
- **Panel deslizable**: al deslizar hacia arriba el panel del botón de grabar
  se ve el cronómetro y la onda (en gris) **sin empezar a grabar**; se graba al
  pulsar el botón. Al deslizarlo hacia abajo se vuelve a plegar.
- **Onda en tiempo real** con el nivel del micrófono.
- **Descartar** una grabación en curso (con confirmación).
- **Lista de grabaciones** ordenada de la más reciente a la más antigua, con
  fecha («Hoy», «Ayer»…), duración y la **onda completa de cada una**.
- **Reproductor integrado**: la onda hace de barra de progreso; se puede tocar
  o arrastrar para saltar a cualquier punto (también en grabaciones que no se
  están reproduciendo).
- **Modo de edición** (menú de cada grabación → *Editar*):
  - **Recortar** con dos asas sobre la onda.
  - **Subir o bajar el volumen** (de −20 a +20 dB) y **normalizar** (lleva el
    pico de la selección a −1 dBFS). Avisa si el volumen elegido satura.
  - **Fundido de entrada y de salida** (hasta 5 s).
  - Escuchar la selección antes de guardar.
  - Guardar **reemplazando** la original o **como copia** («… (editada)»).
- **Renombrar**, **compartir** (con el nombre que le hayas dado) y
  **eliminar** grabaciones.
- **Opciones** (botón ⚙ arriba a la derecha):
  - **Carpeta del dispositivo**: guarda una copia de cada grabación en la
    carpeta que elijas (almacenamiento interno, tarjeta SD, iCloud Drive…).
  - **Google Drive**: guarda una copia de cada grabación en la carpeta
    «Grabadora» de tu Drive. Necesita configuración previa (ver
    [Google Drive](#google-drive)).
- Tema claro y oscuro según el sistema; interfaz en español.

Las grabaciones se guardan en AAC (`.m4a`, mono, 44,1 kHz, 128 kbps) en la
carpeta privada de la app, junto con un índice `recordings.json` que guarda el
nombre, la fecha, la duración, la onda y el estado de las copias de cada una.

### Copias en una carpeta y en Google Drive

La app sigue guardando todo en su carpeta privada (así grabar, reproducir y
editar no depende de permisos ni de la red) y, además, mantiene una copia de
cada grabación en los destinos activados, con el nombre que le hayas dado
(`Reunión con el equipo.m4a`):

- Al grabar, editar o renombrar, la copia se crea, se sobrescribe o se
  renombra. Solo se sube lo que ha cambiado.
- Si algo falla (sin conexión, permiso retirado…), se reintenta al volver a la
  app o con *Opciones → Copiar ahora*. Los errores se ven en las opciones y con
  un icono en la barra superior.
- **Las copias no se borran** al eliminar una grabación en la app ni al
  desactivar un destino.
- Es una copia en un solo sentido: los cambios que hagas directamente en la
  carpeta o en Drive no vuelven a la app.

En Android la carpeta se elige con el selector del sistema y el permiso se
conserva entre reinicios. En iOS se usa el selector de archivos (En mi iPhone,
iCloud Drive…) y un marcador de seguridad.

## Requisitos

- Flutter 3.47 o superior (Dart 3.13).
- Android 7.0 (API 24) o superior.
- iOS 15 o superior.

## Cómo ejecutarla

```bash
flutter pub get
flutter run            # en un dispositivo o emulador conectado
```

Para generar los instalables:

```bash
flutter build apk --release   # Android
flutter build ipa             # iOS (requiere macOS y Xcode)
```

> Si no hay clave de firma configurada, el APK de `release` se firma con la
> clave de depuración. Mira [Firma del APK](#firma-del-apk).

## Permisos

- **Android**: `RECORD_AUDIO` e `INTERNET` (para Google Drive), declarados en
  `android/app/src/main/AndroidManifest.xml`. La carpeta de las copias no
  necesita permisos de almacenamiento: el usuario la elige con el selector
  del sistema.
- **iOS**: `NSMicrophoneUsageDescription`, en `ios/Runner/Info.plist`.

El permiso se pide la primera vez que se pulsa el botón de grabar. Si se
deniega, la app avisa de que hay que activarlo en los ajustes.

## Estructura del código

```
lib/
├── main.dart                     Punto de entrada
├── app.dart                      MaterialApp, tema y localización
├── models/recording.dart         Grabación (nombre, duración, onda, copias…)
├── audio/
│   ├── levels.dart               Niveles de la onda (dBFS → 0–1) y remuestreo
│   ├── wav.dart                  Lectura y escritura de WAV por bloques
│   └── audio_edit.dart           Recorte, volumen, fundidos y picos
├── controllers/
│   ├── recorder_controller.dart  Estado de la grabación (cronómetro, onda…)
│   └── player_controller.dart    Estado de la reproducción
├── services/
│   ├── audio_recorder_service.dart  Micrófono (paquete `record`)
│   ├── audio_player_service.dart    Reproducción (paquete `audioplayers`)
│   ├── audio_codec.dart             m4a ↔ WAV con los códecs del sistema
│   ├── recording_editor.dart        Editar y calcular ondas (en un isolate)
│   ├── recordings_repository.dart   Archivos y metadatos en disco
│   ├── settings_store.dart          Opciones de la app
│   ├── folder_access.dart           Carpeta elegida por el usuario
│   ├── google_drive.dart            Google Sign-In y API REST de Drive
│   ├── copy_sync.dart               Copias en la carpeta y en Drive
│   └── share_service.dart           Compartir (paquete `share_plus`)
├── screens/                      Pantalla principal, editor y opciones
├── widgets/                      Panel de grabación, ondas, elementos de la lista y diálogos
└── utils/                        Formatos de duraciones y fechas, archivos

packages/voicerecorder_native/    Plugin propio con el código nativo
├── android/…/AudioCodecHandler.kt   MediaExtractor + MediaCodec + MediaMuxer
├── android/…/FolderAccess.kt        Storage Access Framework
├── ios/…/AudioCodecHandler.swift    AVAudioFile
└── ios/…/FolderAccessHandler.swift  UIDocumentPicker + marcadores de seguridad
```

La edición funciona así: el `.m4a` se decodifica a WAV con el códec del
sistema, el recorte, el volumen y los fundidos se aplican en Dart (por
bloques y en un isolate aparte, así que no carga el audio entero en memoria ni
bloquea la interfaz) y el resultado se vuelve a codificar en AAC. Mientras se
edita, el audio ocupa unos 5 MB por minuto en la carpeta temporal.

Los servicios de audio, el almacenamiento, la carpeta y Drive están detrás de
interfaces, de modo que los tests usan versiones falsas y no necesitan un
dispositivo.

## Tests

```bash
flutter analyze
flutter test
```

Hay tests unitarios del procesado de audio (WAV, recorte, volumen, fundidos,
picos), del editor, del almacenamiento, de las copias en carpeta y Drive (la
API de Drive se prueba con un cliente HTTP falso), de los controladores y de
los formatos, y tests de widgets de los flujos principales (grabar, desplegar
el panel sin grabar, saltar en la onda, editar, opciones, renombrar y
eliminar).

## Integración continua (GitHub Actions)

### `build.yml`: tests y compilación

Se ejecuta en cada push a cualquier rama, a mano desde la pestaña *Actions* y
desde `release.yml`:

1. **Tests**: `flutter analyze` y `flutter test`.
2. **Android (APK)** en Ubuntu y **iOS (IPA)** en macOS, en paralelo, solo si
   los tests pasan.

El APK y el IPA quedan como artefactos descargables en la ejecución
(`android-apk` e `ios-ipa`).

### `release.yml`: publicar una versión

*Actions → Release → Run workflow*, elige la rama (normalmente `main`) y qué
parte de la versión subir:

| Incremento | Ejemplo, partiendo de `1.4.2+7` |
|------------|---------------------------------|
| `patch`    | `1.4.3+8`                       |
| `minor`    | `1.5.0+8`                       |
| `major`    | `2.0.0+8`                       |

El workflow calcula la nueva versión a partir de `pubspec.yaml` y compila con
`build.yml`. Solo si la compilación termina bien:

- hace un commit «Versión x.y.z» en la rama con el `pubspec.yaml` actualizado,
- crea la etiqueta `vx.y.z`,
- publica la release de GitHub con el APK y el IPA adjuntos y las notas
  generadas a partir de los cambios.

Si algo falla antes, no se sube ni se etiqueta nada. Si la rama está
protegida, permite que GitHub Actions haga push a ella; si no, el último paso
fallará.

### Firma del APK

Android solo instala una actualización si está firmada con la misma clave que
la versión instalada. Para que cada release pueda instalarse encima de la
anterior, crea una clave una vez y guárdala en los secretos del repositorio
(*Settings → Secrets and variables → Actions*):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
base64 -w0 upload-keystore.jks   # valor de ANDROID_KEYSTORE_BASE64
```

| Secreto                     | Valor                                  |
|-----------------------------|----------------------------------------|
| `ANDROID_KEYSTORE_BASE64`   | El keystore codificado en base64       |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del keystore                |
| `ANDROID_KEY_ALIAS`         | Alias de la clave (`upload` en el ejemplo) |
| `ANDROID_KEY_PASSWORD`      | Contraseña de la clave                 |

Guarda una copia del keystore en un lugar seguro: si se pierde, las nuevas
versiones no podrán instalarse encima de las anteriores.

Sin estos secretos el APK se firma con una clave de depuración distinta en
cada ejecución y el workflow muestra un aviso. Para firmar en local, crea
`android/key.properties` (está en `.gitignore`):

```properties
storeFile=/ruta/a/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

### Google Drive

Para poder conectar Google Drive hay que registrar la app en Google Cloud
una vez. Sin esta configuración la app funciona igual, pero la opción de
Google Drive aparece desactivada.

1. En [Google Cloud Console](https://console.cloud.google.com/), crea un
   proyecto y activa la **Google Drive API**.
2. Configura la **pantalla de consentimiento de OAuth** (tipo *Externo*) y
   añade el permiso `https://www.googleapis.com/auth/drive.file`, que solo da
   acceso a los archivos que crea la app. Mientras esté en modo de prueba,
   añade tu cuenta como usuario de prueba.
3. En *Credenciales*, crea tres **ID de cliente de OAuth**:
   - **Android**: paquete `es.germade.voicerecorder` y la huella SHA-1 de la
     clave con la que se firma el APK
     (`keytool -list -v -keystore upload-keystore.jks -alias upload`).
     Sin los secretos `ANDROID_*` cada compilación de CI usa una clave
     distinta y el inicio de sesión fallará.
   - **Aplicación web**: no hay que configurar nada más; Android lo necesita
     como `serverClientId`.
   - **iOS**: ID de paquete `es.germade.voicerecorder`.
4. En el repositorio, *Settings → Secrets and variables → Actions →
   Variables*, crea estas **variables** (los ID de cliente no son secretos):

   | Variable                  | Valor                                   |
   |---------------------------|-----------------------------------------|
   | `GOOGLE_SERVER_CLIENT_ID` | ID de cliente **web** (`…apps.googleusercontent.com`) |
   | `GOOGLE_IOS_CLIENT_ID`    | ID de cliente **iOS**                   |

`build.yml` los pasa a la app con `--dart-define` y, en iOS, genera el
esquema de URL de vuelta del inicio de sesión (el ID de cliente invertido).
Si faltan, el workflow lo indica con un aviso.

Para probarlo en local:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=…                 # Android
flutter run --dart-define=GOOGLE_IOS_CLIENT_ID=1234-abc.apps.googleusercontent.com  # iOS
```

En iOS crea además `ios/Flutter/GoogleSignIn.xcconfig` (está en
`.gitignore`) con el ID invertido:

```
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234-abc
```

### IPA de iOS

El IPA se genera **sin firmar**, porque firmarlo requiere una cuenta de
desarrollador de Apple. Para instalarlo en un iPhone hay que firmarlo, por
ejemplo con AltStore o Sideloadly.

## Limitaciones conocidas

- La grabación está pensada para hacerse con la app en primer plano. Para
  grabar con la pantalla apagada haría falta un servicio en primer plano en
  Android y el modo de audio en segundo plano en iOS.
- En el editor, la escucha previa reproduce la selección con el volumen
  original y sin los fundidos: el resultado se oye al guardar. La onda sí
  muestra el efecto.
- Las copias en la carpeta y en Drive se hacen con la app abierta; no hay
  subida en segundo plano.
