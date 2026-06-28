import 'package:flutter/material.dart';

/// Shown when the camera cannot start (simulator, permission denied, etc.).
class CameraUnavailableScreen extends StatelessWidget {
  const CameraUnavailableScreen({super.key, this.detail});

  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Camera unavailable',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              detail ??
                  'Use a physical iPhone or Android device for live scanning.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Collection, Home, and Settings work without a camera.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
