import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/library/widgets.dart';

void main() {
  test('every icon is drawn from the bundled Phosphor font', () {
    for (final icon in [AppIcons.headphones, AppIcons.folder, AppIcons.back, AppIcons.rescan]) {
      expect(icon.fontFamily, 'Phosphor');
      expect(icon.fontPackage, isNull);
    }
  });
}
