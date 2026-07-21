import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'audio/audio_controller.dart';
import 'state/player_progress.dart';
import 'state/save_service.dart';

/// Entry point.
///
/// The game is landscape only, offline only, and needs its save data and audio
/// settings before the first screen appears.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final save = SaveService();
  await save.init();

  final progress = PlayerProgress(save)..load();
  final audio = AudioController(save);

  runApp(NovaStrikeApp(audio: audio, progress: progress, save: save));
}
