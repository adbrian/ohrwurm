import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'access_screens.dart';
import 'first_launch_screen.dart';
import 'library_controller.dart';
import 'library_screen.dart';
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
      LibraryView.library => const LibraryScreen(),
      LibraryView.result => const RescanResultScreen(),
      LibraryView.stale => const StaleAccessScreen(),
      LibraryView.looksLikePack => const LooksLikePackScreen(),
    };
  }
}
