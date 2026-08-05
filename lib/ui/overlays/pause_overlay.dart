import 'package:flutter/material.dart';

import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../theme/typography.dart';
import '../widgets/nova_button.dart';
import '../widgets/space_scrim.dart';
import '../widgets/volume_slider.dart';

/// The pause menu.
///
/// It carries the same three sliders as the settings screen in compact form,
/// so volume can be changed mid fight without leaving the level. The sliders
/// sit above the choices in one column, because half of a portrait screen is
/// not wide enough for a button to say QUIT TO MENU without eliding it.
class PauseOverlay extends StatefulWidget {
  const PauseOverlay({required this.game, super.key});

  final NovaGame game;

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay> {
  @override
  Widget build(BuildContext context) {
    final audio = widget.game.audio;

    return SpaceScrim(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PAUSED', style: AppType.heading),
                  const SizedBox(height: 10),
                  VolumeSlider(
                    label: 'Master',
                    value: audio.master,
                    compact: true,
                    enabled: !audio.muted,
                    onChanged: (value) {
                      setState(() {});
                      audio.setMaster(value);
                    },
                  ),
                  VolumeSlider(
                    label: 'Music',
                    value: audio.music,
                    compact: true,
                    enabled: !audio.muted,
                    onChanged: (value) {
                      setState(() {});
                      audio.setMusic(value);
                    },
                  ),
                  VolumeSlider(
                    label: 'Effects',
                    value: audio.sfx,
                    compact: true,
                    enabled: !audio.muted,
                    onChanged: (value) {
                      setState(() {});
                      audio.setSfx(value);
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      NovaIconButton(
                        icon: audio.muted ? Icons.volume_off : Icons.volume_up,
                        onPressed: () {
                          audio.setMuted(!audio.muted);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        audio.muted ? 'MUTED' : 'SOUND ON',
                        style: AppType.hudSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  NovaButton(
                    label: 'RESUME',
                    primary: true,
                    icon: Icons.play_arrow,
                    onPressed: () {
                      audio.play(Sfx.buttonTap);
                      widget.game.resumeGame();
                    },
                  ),
                  const SizedBox(height: 10),
                  NovaButton(
                    label: 'RESTART',
                    icon: Icons.refresh,
                    onPressed: () {
                      audio.play(Sfx.buttonTap);
                      widget.game.retry();
                    },
                  ),
                  const SizedBox(height: 10),
                  NovaButton(
                    label: 'QUIT TO MENU',
                    icon: Icons.exit_to_app,
                    onPressed: () {
                      audio.play(Sfx.buttonTap);
                      widget.game.onQuit?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
