import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'library_controller.dart';
import 'widgets.dart';

/// No folder chosen yet (DESIGN 1).
class FirstLaunchScreen extends StatelessWidget {
  const FirstLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    return AppPage(
      children: [
        const SizedBox(height: AppSpace.xxl),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent900,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: AppColors.accent, width: AppBorder.interactive),
            ),
            child: const Icon(AppIcons.headphones, color: AppColors.accent, size: 28),
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Text(Copy.firstLaunchHeading, style: AppTextStyles.heading),
        const SizedBox(height: AppSpace.md),
        Text(Copy.firstLaunchBody, style: AppTextStyles.body),
        const SizedBox(height: AppSpace.xl),
        for (final (i, step) in Copy.firstLaunchSteps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSpace.xl,
                  child: Text(
                    '${i + 1}',
                    style: AppText.german(15)
                        .copyWith(color: AppColors.accent300, fontFeatures: AppText.tabular),
                  ),
                ),
                Expanded(child: Text(step, style: AppText.english(15))),
              ],
            ),
          ),
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
