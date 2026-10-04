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

> La compilación `release` de Android se firma de momento con la clave de
> depuración. Antes de publicar en Google Play, configura tu propia firma en
> `android/app/build.gradle.kts`.

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

## Limitaciones conocidas

- La grabación está pensada para hacerse con la app en primer plano. Para
  grabar con la pantalla apagada haría falta un servicio en primer plano en
  Android y el modo de audio en segundo plano en iOS.
