import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/audio_controller.dart';
import '../../audio/sfx.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/star_field.dart';
import '../widgets/nova_button.dart';
import '../widgets/volume_slider.dart';

/// Sound, haptics and the reset progress button.
///
/// Moving a slider applies straight away, and the value is written to disk
/// after a short debounce rather than on every frame of the drag.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String route = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AudioController _audio;
  late double _master;
  late double _music;
  late double _sfx;
  late bool _muted;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    // Held onto here rather than looked up in dispose, because the scope is
    // gone by the time this screen is torn down.
    _audio = AppScope.of(context).audio;
    _master = _audio.master;
    _music = _audio.music;
    _sfx = _audio.sfx;
    _muted = _audio.muted;
  }

  @override
  void dispose() {
    // Write anything the debounce has not flushed yet.
    _audio.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final audio = scope.audio;
    final progress = scope.progress;

    return StarField(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('SETTINGS', style: AppType.subheading),
          centerTitle: true,
        ),
        body: SafeArea(
          // One column. Two half width lists in portrait squeezed every switch
          // and its explanation into a strip too narrow to read.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ListView(
              children: [
                Text('AUDIO', style: AppType.hudSmall),
                const SizedBox(height: 8),
                VolumeSlider(
                  label: 'Master',
                  value: _master,
                  enabled: !_muted,
                  onChanged: (value) {
                    setState(() => _master = value);
                    audio.setMaster(value);
                  },
                  onChangeEnd: (_) => audio.play(Sfx.buttonTap),
                ),
                VolumeSlider(
                  label: 'Music',
                  value: _music,
                  enabled: !_muted,
                  onChanged: (value) {
                    setState(() => _music = value);
                    audio.setMusic(value);
                  },
                ),
                VolumeSlider(
                  label: 'Effects',
                  value: _sfx,
                  enabled: !_muted,
                  onChanged: (value) {
                    setState(() => _sfx = value);
                    audio.setSfx(value);
                  },
                  onChangeEnd: (_) => audio.play(Sfx.buttonTap),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  value: _muted,
                  title: Text('Mute everything', style: AppType.body),
                  subtitle: Text(
                    'Keeps your slider levels for when you switch it back on',
                    style: AppType.bodyDim,
                  ),
                  activeThumbColor: Palette.uiAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() => _muted = value);
                    audio.setMuted(value);
                  },
                ),
                const SizedBox(height: 8),
                const Divider(color: Palette.uiPanelLight),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => SwitchListTile(
                    value: progress.hapticsEnabled,
                    title: Text('Haptics', style: AppType.body),
                    subtitle: Text(
                      'Short vibration when the ship is hit',
                      style: AppType.bodyDim,
                    ),
                    activeThumbColor: Palette.uiAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: progress.setHaptics,
                  ),
                ),
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => SwitchListTile(
                    value: progress.reduceShake,
                    title: Text('Reduce shake', style: AppType.body),
                    subtitle: Text(
                      'The camera holds still when things explode',
                      style: AppType.bodyDim,
                    ),
                    activeThumbColor: Palette.uiAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: progress.setReduceShake,
                  ),
                ),
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => SwitchListTile(
                    value: progress.highContrast,
                    title: Text('High contrast fire', style: AppType.body),
                    subtitle: Text(
                      'Enemy shots move away from the colour of yours',
                      style: AppType.bodyDim,
                    ),
                    activeThumbColor: Palette.uiAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: progress.setHighContrast,
                  ),
                ),
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => SwitchListTile(
                    value: progress.largeBullets,
                    title: Text('Large bullets', style: AppType.body),
                    subtitle: Text(
                      'Drawn bigger. What they hit does not change',
                      style: AppType.bodyDim,
                    ),
                    activeThumbColor: Palette.uiAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: progress.setLargeBullets,
                  ),
                ),
                const Divider(color: Palette.uiPanelLight),
                const SizedBox(height: 12),
                Text('PROGRESS', style: AppType.hudSmall),
                const SizedBox(height: 12),
                NovaButton(
                  label: 'RESET PROGRESS',
                  icon: Icons.delete_forever,
                  onPressed: () => _confirmReset(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final scope = AppScope.of(context);
    scope.audio.play(Sfx.buttonTap);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.uiPanel,
        title: Text('Reset progress', style: AppType.heading),
        content: Text(
          'This clears every unlocked level, all coins, all upgrades and all '
          'stars. Audio settings are kept. This cannot be undone.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('CANCEL', style: AppType.body),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'RESET',
              style: AppType.body.copyWith(color: Palette.bossHealthBar),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await scope.progress.resetProgress();
    }
  }
}
