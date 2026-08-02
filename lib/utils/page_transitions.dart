// ============================================================
// utils/page_transitions.dart  –  Shared Slide Transitions
// ============================================================
// Two named transitions used consistently across the sign-up /
// sign-in flow, so the direction of travel always means the same
// thing to the user:
//   • slideFromRight  — "moving forward" (e.g. Welcome → Create
//     Account → PIN setup). The new screen sweeps in from the
//     right and settles, reading as progress.
//   • slideFromLeft   — "returning" (e.g. Welcome → Sign In →
//     restoring an existing account). The new screen sweeps in
//     from the left, reading as going back to something that
//     already exists rather than starting fresh.
// ============================================================

import 'package:flutter/material.dart';

Route<T> slideFromRight<T>(Widget page) => _slideRoute<T>(page, fromRight: true);
Route<T> slideFromLeft<T>(Widget page) => _slideRoute<T>(page, fromRight: false);

Route<T> _slideRoute<T>(Widget page, {required bool fromRight}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final begin = fromRight ? const Offset(1, 0) : const Offset(-1, 0);
      final slide = Tween(begin: begin, end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation);
      final fade = CurveTween(curve: const Interval(0.2, 1.0)).animate(animation);
      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}
