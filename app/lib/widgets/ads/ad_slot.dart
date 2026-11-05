import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/ad_service.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';

/// The bottom embed that holds a banner ad.
///
/// Until an ad is ready the slot is **zero height with no gap, no border and no
/// placeholder**. It is also collapsed while ads are off, while the keyboard is
/// open, and while another screen covers this one, so a hidden screen never
/// keeps a banner alive. When the app returns to the foreground after a failed
/// load it asks for a new banner.
class AdSlot extends StatefulWidget {
  const AdSlot({
    required this.service,
    required this.enabled,
    super.key,
    this.gapAbove = AppSizes.adSlotGapAbove,
    this.safeBottom = false,
  });

  final AdService service;

  /// Whether banners may be requested at all (consent given, SDK running).
  final ValueListenable<bool> enabled;

  /// Space above the ad. The viewer uses a larger gap so the ad never sits
  /// next to its Save button.
  final double gapAbove;

  /// Adds the bottom system inset under the ad, for screens that are not
  /// wrapped in a safe area.
  final bool safeBottom;

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> with WidgetsBindingObserver {
  BannerHandle? _banner;
  Animation<double>? _secondary;
  bool _covered = false;
  int _width = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.enabled.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _width = MediaQuery.sizeOf(context).width.floor();
    final Animation<double>? animation = ModalRoute.of(
      context,
    )?.secondaryAnimation;
    if (animation != _secondary) {
      _secondary?.removeStatusListener(_onRouteStatus);
      _secondary = animation;
      animation?.addStatusListener(_onRouteStatus);
      _covered =
          animation != null && animation.status != AnimationStatus.dismissed;
    }
    _sync();
  }

  @override
  void didUpdateWidget(AdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      oldWidget.enabled.removeListener(_sync);
      widget.enabled.addListener(_sync);
    }
    if (oldWidget.service != widget.service) {
      _release();
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _banner?.state.value == AdState.failed) {
      _release();
      _sync();
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    final bool covered = status != AnimationStatus.dismissed;
    if (covered != _covered) {
      _covered = covered;
      _sync();
    }
  }

  void _release() {
    _banner?.dispose();
    _banner = null;
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    final bool want = widget.enabled.value && !_covered && _width > 0;
    if (want && _banner == null) {
      _banner = widget.service.createBanner(_width);
      setState(() {}); // ui-local
    } else if (!want && _banner != null) {
      _release();
      setState(() {}); // ui-local
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.enabled.removeListener(_sync);
    _secondary?.removeStatusListener(_onRouteStatus);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerHandle? banner = _banner;
    if (banner == null || MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<AdState>(
      valueListenable: banner.state,
      builder: (BuildContext context, AdState state, Widget? child) {
        final Widget? ad = banner.widget;
        if (state != AdState.ready || ad == null) {
          return const SizedBox.shrink();
        }
        return Semantics(
          container: true,
          label: l10n.adSlotLabel,
          child: Padding(
            padding: EdgeInsets.only(top: widget.gapAbove),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.borderSubtle,
                    width: AppSizes.hairline,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  // The border is painted, not laid out, so reserve its space.
                  top: AppSizes.hairline,
                  bottom: widget.safeBottom
                      ? MediaQuery.paddingOf(context).bottom
                      : 0,
                ),
                child: Center(heightFactor: 1, child: ad),
              ),
            ),
          ),
        );
      },
    );
  }
}
