// lib/index_page.dart
import 'package:flutter/material.dart';

/// Minimal IndexPage kept as a harmless, unconnected placeholder.
/// The app routes do not reference this page anymore; it's present only
/// so tests or other code that import IndexPage don't break.
class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ಮಾತೃತ್ವ ಆರೋಗ್ಯ ಸಹಾಯಕ', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              child: const Text('ಮಾಹಿತಿ'),
            ),
          ],
        ),
      ),
    );
  }
}