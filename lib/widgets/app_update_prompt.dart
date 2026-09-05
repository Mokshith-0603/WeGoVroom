import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/trip_link_service.dart';
import '../theme/app_theme.dart';

class AppUpdatePrompt extends StatefulWidget {
  const AppUpdatePrompt({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends State<AppUpdatePrompt> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (_checked || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _checked = true;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (!mounted ||
          updateInfo.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.system_update_rounded,
              color: AppTheme.brandOrange,
              size: 38,
            ),
            title: const Text('Update available'),
            content: const Text(
              'A new version of WeGoVroom is available. Update now to get the latest improvements and fixes.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openPlayStore();
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Update'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      // Play's update API is unavailable for debug/sideloaded builds.
      debugPrint('Unable to check for a Play Store update: $error');
    }
  }

  Future<void> _openPlayStore() async {
    final opened = await launchUrl(
      TripLinkService.instance.playStoreUri(),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Play Store')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
