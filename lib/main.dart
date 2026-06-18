import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/scan_screen.dart';
import 'theme/element3_theme.dart';

void main() {
  runApp(const ProviderScope(child: Element3App()));
}

class Element3App extends StatelessWidget {
  const Element3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Element 3',
      debugShowCheckedModeBanner: false,
      theme: Element3Theme.dark,
      home: const ScanScreen(),
    );
  }
}
