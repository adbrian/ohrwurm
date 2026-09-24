import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../packs/pack_storage.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'library_controller.dart';
import 'widgets.dart';

/// The saved folder can't be read (APP_SPEC 5.3). Offers *Try again* first and keeps the saved
/// folder; never shows an empty library.
class StaleAccessScreen extends StatelessWidget {
  const StaleAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final busy = library.scanning;
    final why = library.access == RootAccess.denied ? Copy.staleDenied : Copy.staleMissing;
    return AppPage(
      children: [
        const SizedBox(height: AppSpace.xxl),
        Text(Copy.staleHeading, style: AppTextStyles.heading),
        const SizedBox(height: AppSpace.lg),
        FolderTile(location: library.location ?? ''),
        const SizedBox(height: AppSpace.lg),
        Text('$why ${Copy.staleKept}', style: AppTextStyles.body),
        const SizedBox(height: AppSpace.xl),
        OutlinedButton(
          style: AppButtons.primary,
          onPressed: busy ? null : library.tryAgain,
          child: const Text(Copy.tryAgain),
        ),
        const SizedBox(height: AppSpace.md),
        OutlinedButton(
          onPressed: busy ? null : library.chooseFolder,
          child: const Text(Copy.chooseFolder),
        ),
      ],
    );
  }
}

/// The chosen folder is a single pack (APP_SPEC 5.1). Nothing was scanned or saved.
class LooksLikePackScreen extends StatelessWidget {
  const LooksLikePackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    return AppPage(
      leading: PlainIconButton(
        icon: AppIcons.back,
        tooltip: Copy.back,
        onPressed: library.closeLooksLikePack,
      ),
      children: [
        const SizedBox(height: AppSpace.xl),
        Text(Copy.onePackHeading, style: AppTextStyles.heading),
        const SizedBox(height: AppSpace.md),
        Text(Copy.onePackBody, style: AppTextStyles.body),
        const SizedBox(height: AppSpace.xl),
        OutlinedButton(
          style: AppButtons.primary,
          onPressed: library.scanning ? null : library.chooseFolder,
          child: const Text(Copy.chooseFolder),
        ),
      ],
    );
  }
}

/// A folder is saved but nothing has loaded yet: the first rescan is running. Plain text, no
/// spinner.
class FirstScanScreen extends StatelessWidget {
  const FirstScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(Copy.firstScan, style: AppText.english(15))),
    );
  }
}
