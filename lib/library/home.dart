import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../session/resume_screen.dart';
import '../session/setup_controller.dart';
import '../session/setup_screen.dart';
import 'access_screens.dart';
import 'first_launch_screen.dart';
import 'library_controller.dart';
import 'rescan_result_screen.dart';

/// Shows the screen for the library's current state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final view = context.select<LibraryController, LibraryView>((c) => c.view);
    return switch (view) {
      LibraryView.starting => const Scaffold(),
      LibraryView.firstLaunch => const FirstLaunchScreen(),
      LibraryView.firstScan => const FirstScanScreen(),
      LibraryView.library => const _Library(),
      LibraryView.result => const RescanResultScreen(),
      LibraryView.stale => const StaleAccessScreen(),
      LibraryView.looksLikePack => const LooksLikePackScreen(),
    };
  }
}

/// The saved session is offered first, once per launch (APP_SPEC 10.2); then setup, the main
/// entry point (DESIGN 4).
class _Library extends StatelessWidget {
  const _Library();

  @override
  Widget build(BuildContext context) {
    final offer = context.select<SetupController, Session?>((s) => s.resumeOffer);
    if (offer != null) return ResumeScreen(key: ObjectKey(offer), session: offer);
    return const SetupScreen();
  }
}
