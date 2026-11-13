import 'dart:async';

import 'package:flutter/material.dart';

class FermsLoadingIndicator extends StatefulWidget {
  const FermsLoadingIndicator({super.key, this.size = 40});

  final double size;

  @override
  State<FermsLoadingIndicator> createState() => _FermsLoadingIndicatorState();
}

class _FermsLoadingIndicatorState extends State<FermsLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.78,
    upperBound: 1,
  );
  bool? _reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion == reducedMotion) return;
    _reducedMotion = reducedMotion;
    if (reducedMotion) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading MCC FERMS',
    liveRegion: true,
    child: SizedBox.square(
      dimension: widget.size,
      child: Center(
        child: ScaleTransition(
          scale: _controller,
          child: Text(
            'M',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: widget.size * 0.85,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    ),
  );
}

class FermsAppear extends StatefulWidget {
  const FermsAppear({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FermsAppear> createState() => _FermsAppearState();
}

class _FermsAppearState extends State<FermsAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Timer? _timer;
  bool? _reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion == reducedMotion) return;
    _reducedMotion = reducedMotion;
    _timer?.cancel();
    if (reducedMotion) {
      _controller.value = 1;
      return;
    }
    final delay = Duration(milliseconds: widget.index.clamp(0, 8) * 70);
    _timer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final progress = _reducedMotion == true ? 1.0 : _controller.value;
      return Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 12),
          child: child,
        ),
      );
    },
  );
}

PageRoute<T> fermsPageRoute<T>(Widget page) {
  final reducedMotion = WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 260),
    reverseTransitionDuration: reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
