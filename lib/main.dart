import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  runApp(Provider<AppDatabase>.value(value: database, child: const OhrwurmApp()));
}

class OhrwurmApp extends StatelessWidget {
  const OhrwurmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ohrwurm',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const _Placeholder(),
    );
  }
}

/// Stands in until the first-launch and pack screens arrive in step A2.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Ohrwurm', style: AppText.german(30))),
    );
  }
}
