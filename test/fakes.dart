import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:voicerecorder/models/recording.dart';
import 'package:voicerecorder/services/audio_player_service.dart';
import 'package:voicerecorder/services/audio_recorder_service.dart';
import 'package:voicerecorder/services/recordings_repository.dart';

class FakeAudioRecorderService implements AudioRecorderService {
  FakeAudioRecorderService({
    this.permissionGranted = true,
    this.writeFiles = false,
  });

  bool permissionGranted;

  /// Si es `true`, `start` crea un archivo real en la ruta indicada.
  final bool writeFiles;

  final calls = <String>[];
  final statusController = StreamController<RecorderStatus>.broadcast();
  final amplitudeController = StreamController<double>.broadcast();
  String? path;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    return permissionGranted;
  }

  @override
  Future<void> start(String path) async {
    calls.add('start');
    this.path = path;
    if (writeFiles) File(path).writeAsBytesSync([0, 1, 2, 3]);
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<String?> stop() async {
    calls.add('stop');
    return path;
  }

  @override
  Future<void> cancel() async => calls.add('cancel');

  @override
  Stream<RecorderStatus> statusChanges() => statusController.stream;

  @override
  Stream<double> amplitudeChanges(Duration interval) =>
      amplitudeController.stream;

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeAudioPlayerService implements AudioPlayerService {
  final calls = <String>[];
  final statusController = StreamController<PlaybackStatus>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  bool disposed = false;

  @override
  Stream<PlaybackStatus> get statusChanges => statusController.stream;

  @override
  Stream<Duration> get positionChanges => positionController.stream;

  @override
  Stream<Duration> get durationChanges => durationController.stream;

  @override
  Future<void> play(String path, {Duration? position}) async {
    calls.add('play $path @${position?.inMilliseconds ?? 0}');
    statusController.add(PlaybackStatus.playing);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    statusController.add(PlaybackStatus.paused);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    statusController.add(PlaybackStatus.playing);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    statusController.add(PlaybackStatus.stopped);
  }

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inMilliseconds}');

  @override
  Future<void> dispose() async => disposed = true;
}

class InMemoryRecordingsRepository implements RecordingsRepository {
  InMemoryRecordingsRepository([List<Recording> initial = const []])
    : recordings = [...initial];

  final List<Recording> recordings;
  final discarded = <String>[];
  var _counter = 0;

  @override
  Future<String> createRecordingPath() async => '/fake/rec_${_counter++}.m4a';

  @override
  Future<List<Recording>> loadAll() async =>
      [...recordings]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Recording?> add({
    required String path,
    required Duration duration,
  }) async {
    final recording = Recording(
      id: p.basenameWithoutExtension(path),
      path: path,
      name: FileRecordingsRepository.nextDefaultName(
        recordings.map((r) => r.name),
      ),
      createdAt: DateTime.now(),
      duration: duration,
    );
    recordings.add(recording);
    return recording;
  }

  @override
  Future<Recording> rename(Recording recording, String name) async {
    final renamed = recording.copyWith(name: name);
    final index = recordings.indexWhere((r) => r.id == recording.id);
    recordings[index] = renamed;
    return renamed;
  }

  @override
  Future<void> delete(Recording recording) async =>
      recordings.removeWhere((r) => r.id == recording.id);

  @override
  Future<void> discard(String path) async => discarded.add(path);
}
