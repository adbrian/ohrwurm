import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/main.dart';
import 'package:ohrwurm/theme/tokens.dart';

void main() {
  testWidgets('app starts on the dark theme', (tester) async {
    await tester.pumpWidget(const OhrwurmApp());

    final theme = Theme.of(tester.element(find.text('Ohrwurm')));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.bg);
  });
}
