import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hand_indicator.dart';
import 'tutorial_overlay.dart';

/// How a coach mark is satisfied.
enum TutorialAdvance {
  /// The player has to do the thing. Everything but the hole is blocked, and a
  /// tap on the scrim is refused rather than counted.
  ///
  /// This is what makes a tutorial teach rather than narrate.
  target,

  /// The step is explaining something the player cannot press: a score, a
  /// clock, a meter that fills itself. A tap anywhere moves on.
  ///
  /// Without this, such a thing can only be explained by a step that waits for
  /// an interaction the widget does not offer, and the sequence stalls.
  anywhere,
}

/// One coach mark: a widget to cut a hole around, a gesture to draw over it,
/// and a line to read.
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.target,
    required this.caption,
    this.spot,
    this.gesture = HandGesture.tap,
    this.advance = TutorialAdvance.target,
    this.travel = Offset.zero,
    this.padding = 10,
    this.radius = 22,
  });

  /// What the screen reports when the player does this. Ids are compared, so
  /// they must be unique within a sequence.
  final String id;

  /// The real widget being taught. Its [GlobalKey] is how the hole is measured,
  /// so the widget has to be mounted when the step arrives.
  ///
  /// Ignored when [spot] is given.
  final GlobalKey target;

  /// Where to cut the hole when the thing being pointed at is not a widget.
  ///
  /// An enemy is drawn by the game, not laid out by Flutter, so it has no key
  /// to measure and no render box to find. This hands back its rectangle on
  /// the glass instead, in the same global coordinates a key would have given.
  ///
  /// Returns null when there is nothing to point at yet, which is the normal
  /// state of a lesson that is waiting for something to arrive. The overlay
  /// draws nothing and asks again next frame, exactly as it does for a key
  /// whose widget has not been laid out.
  final Rect? Function()? spot;

  final String caption;
  final HandGesture gesture;
  final TutorialAdvance advance;

  /// For [HandGesture.swipe]: how far and which way the hand travels.
  ///
  /// Given here rather than baked into the animation, because an asset fixes
  /// its motion at author time and rotating a baked sideways sweep to point
  /// downward lays the hand on its side.
  final Offset travel;

  /// How far the hole is grown beyond the target, and how round its corners
  /// are.
  final double padding;
  final double radius;
}

/// Where a sequence records that it has been seen.
///
/// Behind an interface for one specific reason, not for neatness:
/// [SharedPreferences.getInstance] never completes under a widget test binding
/// that has not been given mock values, which turns reading the flag into a
/// way to freeze a screen.
abstract class TutorialStore {
  Future<bool> hasSeen(String flag);
  Future<void> markSeen(String flag);
  Future<void> clear(String flag);
}

class PrefsTutorialStore implements TutorialStore {
  const PrefsTutorialStore();

  @override
  Future<bool> hasSeen(String flag) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(flag) ?? false;
  }

  @override
  Future<void> markSeen(String flag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(flag, true);
  }

  @override
  Future<void> clear(String flag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(flag);
  }
}

/// A store that forgets, for tests and for the everyTime mode.
class MemoryTutorialStore implements TutorialStore {
  final Set<String> _seen = <String>{};

  @override
  Future<bool> hasSeen(String flag) async => _seen.contains(flag);

  @override
  Future<void> markSeen(String flag) async => _seen.add(flag);

  @override
  Future<void> clear(String flag) async => _seen.remove(flag);
}

/// Runs a sequence of coach marks over whatever is already on screen.
///
/// It owns an [OverlayEntry] and nothing else. It does not wrap the screen,
/// intercept its gestures, proxy its callbacks or stand in front of anything.
/// The real control keeps its real handler and its real splash, and simply
/// calls [report] afterwards.
///
/// That matters more than it looks. The alternative, where the tutorial wraps
/// the screen and synthesises the press, gives every control two code paths,
/// and the taught one is the path nobody tests. It also means the first thing
/// a new player does in the game is a fake version of the thing they think
/// they are doing.
class TutorialController extends ChangeNotifier {
  TutorialController({
    required this.steps,
    required this.flag,
    this.everyTime = false,
    TutorialStore? store,
  }) : store = store ?? debugStore ?? const PrefsTutorialStore();

  /// The store every controller built after this is set will use.
  static TutorialStore? debugStore;

  /// Stops every sequence starting at all.
  ///
  /// Needed on top of [debugStore] because an everyTime sequence never reads a
  /// flag, so seeding one cannot turn it off, and a scrim over a test that is
  /// about something else blocks the very taps it is making.
  static bool debugDisabled = false;

  final List<TutorialStep> steps;

  /// Versioned, so a rewritten sequence can be shown again to somebody who saw
  /// the old one.
  final String flag;

  /// Shown every launch rather than once. Worth it for a sequence teaching the
  /// controls: somebody coming back after a month is being taught, not
  /// reminded. In this mode the flag is never read.
  final bool everyTime;

  final TutorialStore store;

  OverlayEntry? _entry;
  int _index = 0;
  bool _running = false;
  int _nudges = 0;

  bool get isRunning => _running;
  int get nudges => _nudges;
  int get index => _index;

  TutorialStep? get current =>
      _running && _index < steps.length ? steps[_index] : null;

  /// Starts unless this sequence has been seen, or tutorials are switched off.
  ///
  /// The flag is read before anything is inserted, paused or disabled. The
  /// other order, where the screen is held and the read is then awaited, makes
  /// that read a single point of failure for the whole screen: a read that
  /// never answers leaves it held forever.
  Future<void> startIfUnseen(BuildContext context) async {
    if (debugDisabled || _running || steps.isEmpty) {
      return;
    }
    if (!everyTime && await store.hasSeen(flag)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    start(context);
  }

  /// Puts the first mark on screen. Restarts a sequence left part finished,
  /// because the controller outlives the screen and one abandoned half way
  /// would otherwise refuse to run again.
  void start(BuildContext context) {
    if (debugDisabled || steps.isEmpty) {
      return;
    }
    _entry?.remove();
    _index = 0;
    _nudges = 0;
    _running = true;
    _entry = OverlayEntry(
      builder: (_) => ListenableBuilder(
        listenable: this,
        builder: (context, _) => TutorialOverlay(controller: this),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    notifyListeners();
  }

  /// Called by the screen after it has done the real thing.
  ///
  /// Unconditional at the call site: an id that is not the current step is
  /// ignored, and nothing happens at all when no sequence is running. A
  /// handler guarded by `if (tutorial.isRunning)` is a handler that will one
  /// day be wrong.
  void report(String id) {
    if (!_running) {
      return;
    }
    if (current?.id != id) {
      return;
    }
    _next();
  }

  /// A tap that landed on the scrim rather than on the thing being taught.
  /// Refused, not counted: it replays the hand and leaves the step alone.
  void nudge() {
    if (!_running) {
      return;
    }
    if (current?.advance == TutorialAdvance.anywhere) {
      _next();
      return;
    }
    _nudges++;
    notifyListeners();
  }

  /// Asks the overlay to look again for a target that was not laid out yet.
  void refresh() {
    if (_running) {
      notifyListeners();
    }
  }

  void _next() {
    _nudges = 0;
    _index++;
    if (_index >= steps.length) {
      finish();
      return;
    }
    notifyListeners();
  }

  /// Ends the sequence and takes the scrim away.
  void finish() {
    if (!_running) {
      return;
    }
    _running = false;
    _entry?.remove();
    _entry = null;
    if (!everyTime) {
      // Not awaited. The mark is gone either way, and a slow disk must not
      // hold the last frame of a tutorial on screen.
      store.markSeen(flag);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // An overlay outliving its controller is an undismissable black screen
    // with no way out of it.
    _entry?.remove();
    _entry = null;
    _running = false;
    super.dispose();
  }
}

/// Starts a sequence once the screen it teaches has a frame.
///
/// The targets are found through their [GlobalKey]s, and a key with nothing
/// mounted under it has no box to measure, so this waits for the first frame
/// rather than starting from [State.initState].
class TutorialLauncher extends StatefulWidget {
  const TutorialLauncher({
    required this.controller,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final TutorialController controller;
  final Widget child;

  /// Held false until the screen is ready to be taught. A game paused before
  /// it has rendered anything shows black, because there is no frame to hold.
  final bool enabled;

  @override
  State<TutorialLauncher> createState() => _TutorialLauncherState();
}

class _TutorialLauncherState extends State<TutorialLauncher> {
  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(TutorialLauncher old) {
    super.didUpdateWidget(old);
    // A screen that switches itself on later gets picked up here, which is why
    // both guards live inside the callback rather than at the call sites.
    if (widget.enabled && !old.enabled) {
      _maybeStart();
    }
  }

  void _maybeStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) {
        return;
      }
      if (TutorialController.debugDisabled) {
        return;
      }
      widget.controller.startIfUnseen(context);
    });
  }

  @override
  void dispose() {
    // Otherwise the scrim survives onto whatever screen comes next.
    widget.controller.finish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
