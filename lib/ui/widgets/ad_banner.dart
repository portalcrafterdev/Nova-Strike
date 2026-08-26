import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ads/ads_controller.dart';
import '../../theme/palette.dart';

/// The banner slot that sits at the bottom of the menu screens.
///
/// It occupies nothing until an ad has actually loaded. A slot that reserves
/// its height up front leaves a grey bar across the bottom of the menu on every
/// phone with no network, which looks like a bug rather than a missing ad.
///
/// It is never placed over the play area. A banner during a level would cover
/// the lane the player is flying in and put a web view on the compositor while
/// the game is trying to hold sixty frames.
class AdBanner extends StatefulWidget {
  const AdBanner({required this.ads, super.key});

  final AdsController ads;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deferred to here rather than initState, because the size wanted depends
    // on how wide the screen is and there is no MediaQuery before this.
    if (!_asked) {
      _asked = true;
      _request();
    }
  }

  Future<void> _request() async {
    if (!widget.ads.isReady) {
      return;
    }
    final width = MediaQuery.sizeOf(context).width.truncate();
    // An anchored adaptive banner is as tall as the phone thinks it should be
    // for that width. It fills the screen properly instead of leaving a 320
    // wide strip marooned in the middle of a 1080 wide phone.
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ??
        AdSize.banner;
    if (!mounted) {
      return;
    }
    final ad = BannerAd(
      size: size,
      adUnitId: widget.ads.bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _loaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      color: Palette.spaceDeep,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
