import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ads_controller.dart';
import 'app.dart';
import 'audio/audio_controller.dart';
import 'services/game_services_controller.dart';
import 'state/player_progress.dart';
import 'state/save_service.dart';

/// Entry point.
///
/// The game is portrait only, offline only, and needs its save data and audio
/// settings before the first screen appears.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final save = SaveService();
  await save.init();

  final progress = PlayerProgress(save)..load();
  final audio = AudioController(save);

  // The store is the one thing here that is allowed to be slow, so it is
  // started rather than waited for. Nothing on the first screen needs its
  // answer, and a phone with no network must not sit on a black window.
  final games = GameServicesController()..watch(progress);
  unawaited(games.init());

  // Same treatment, for the same reason. Starting the ad plugin reaches the
  // network, and the menu must not wait on it. Nothing on screen depends on an
  // ad, so the banner simply appears if and when one arrives.
  final ads = AdsController();
  unawaited(ads.init());

  runApp(
    NovaStrikeApp(
      audio: audio,
      progress: progress,
      save: save,
      games: games,
      ads: ads,
    ),
  );
}
