# Grabadora de voz

Aplicación móvil (Android e iOS) hecha con Flutter para grabar, escuchar y
gestionar notas de voz.

<p>
  <img src="docs/lista.png" width="260" alt="Lista de grabaciones con una en reproducción">
  <img src="docs/grabando.png" width="260" alt="Pantalla durante una grabación">
</p>

## Funciones

- **Grabar** con un solo toque, con **pausa/reanudar** y cronómetro.
- **Onda en tiempo real** con el nivel del micrófono.
- **Descartar** una grabación en curso (con confirmación).
- **Lista de grabaciones** ordenada de la más reciente a la más antigua, con
  fecha («Hoy», «Ayer»…) y duración.
- **Reproductor integrado**: reproducir/pausar y barra para saltar a
  cualquier punto.
- **Renombrar**, **compartir** (con el nombre que le hayas dado) y
  **eliminar** grabaciones.
- Tema claro y oscuro según el sistema; interfaz en español.

Las grabaciones se guardan en AAC (`.m4a`, mono, 44,1 kHz, 128 kbps) en la
carpeta privada de la app, junto con un índice `recordings.json` que guarda el
nombre, la fecha y la duración de cada una.

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

- **Android**: `RECORD_AUDIO`, declarado en
  `android/app/src/main/AndroidManifest.xml`.
- **iOS**: `NSMicrophoneUsageDescription`, en `ios/Runner/Info.plist`.

El permiso se pide la primera vez que se pulsa el botón de grabar. Si se
deniega, la app avisa de que hay que activarlo en los ajustes.

## Estructura del código

```
lib/
├── main.dart                     Punto de entrada
├── app.dart                      MaterialApp, tema y localización
├── models/recording.dart         Modelo de una grabación
├── controllers/
│   ├── recorder_controller.dart  Estado de la grabación (cronómetro, onda…)
│   └── player_controller.dart    Estado de la reproducción
├── services/
│   ├── audio_recorder_service.dart  Micrófono (paquete `record`)
│   ├── audio_player_service.dart    Reproducción (paquete `audioplayers`)
│   ├── recordings_repository.dart   Archivos y metadatos en disco
│   └── share_service.dart           Compartir (paquete `share_plus`)
├── screens/home_screen.dart      Pantalla principal
├── widgets/                      Panel de grabación, onda, elementos de la lista y diálogos
└── utils/formatters.dart         Formato de duraciones y fechas
```

Los servicios de audio y el almacenamiento están detrás de interfaces, de modo
que los tests usan versiones falsas y no necesitan un dispositivo.

## Tests

```bash
flutter analyze
flutter test
```

Hay tests unitarios del almacenamiento, los controladores y los formatos, y
tests de widgets de los flujos principales (grabar, pausar, descartar,
reproducir, renombrar y eliminar).

## Integración continua (GitHub Actions)

### `build.yml`: tests y compilación

Se ejecuta en cada push a cualquier rama (salvo si solo cambian archivos
Markdown o `docs/`), a mano desde la pestaña *Actions* y desde `release.yml`:

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

### IPA de iOS

El IPA se genera **sin firmar**, porque firmarlo requiere una cuenta de
desarrollador de Apple. Para instalarlo en un iPhone hay que firmarlo, por
ejemplo con AltStore o Sideloadly.

## Limitaciones conocidas

- La grabación está pensada para hacerse con la app en primer plano. Para
  grabar con la pantalla apagada haría falta un servicio en primer plano en
  Android y el modo de audio en segundo plano en iOS.
