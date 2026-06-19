import 'package:flutter/material.dart';

/// Shown when camera / on-device ML features require a phone or emulator.
class MobileOnlyScreen extends StatelessWidget {
  const MobileOnlyScreen({
    super.key,
    required this.feature,
  });

  final String feature;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_iphone, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '$feature requires a mobile device',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect an Android phone (USB debugging) or iPhone, or run an '
              'Android/iOS emulator. Chrome and macOS can browse your collection '
              'but cannot run on-device camera ML.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Quick start:\n'
              '• Android: install Android Studio → create AVD → flutter run\n'
              '• iPhone: install Xcode → open Simulator → flutter run',
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}
