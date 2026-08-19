import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/ship_mark.dart';
import '../widgets/star_field.dart';
import 'main_menu.dart';

/// The loading screen.
///
/// Every sound effect is decoded here rather than on first use, because a
/// decode stutter in the middle of a boss fight is unacceptable. It carries
/// the same mark, sky and wordmark as the menu it hands over to, so the first
/// thing the player sees is already the game rather than a holding page.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  static const String route = '/';

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _boot();
  }

  Future<void> _boot() async {
    final scope = AppScope.of(context);
    await scope.audio.init();
    await scope.audio.playMusic(MusicTracks.menu);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacementNamed(MainMenu.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.spaceDeep,
      body: StarField(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ShipMark(),
              const SizedBox(height: 4),
              Text('NOVA', style: AppType.titleGlow),
              Text(
                'STRIKE',
                style: AppType.titleGlow.copyWith(color: Palette.uiAccent),
              ),
              const SizedBox(height: 14),
              const SizedBox(width: 210, child: RuleMark()),
              const SizedBox(height: 34),
              // Slim and wide rather than a chunky bar, so it reads as a
              // readout on the sky instead of a control sitting on top of it.
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: Palette.uiAccent,
                    backgroundColor: Palette.panelFill,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('LOADING', style: AppType.hudSmall),
            ],
          ),
        ),
      ),
    );
  }
}
