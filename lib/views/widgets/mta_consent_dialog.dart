import 'package:flutter/material.dart';

Future<bool> showMtaConsentDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable MTA trip offers?'),
        content: const Text(
          'If you enable MTA, your name, phone number, selected vehicle '
          'details, and sensor location fixes received while online will '
          'be sent to MTA to provide trip offers. Offers are polled while '
          'the app is active; background alerts are best-effort only and '
          'are not guaranteed. You can turn this off in Settings at any '
          'time. This is an operational consent notice, not legal terms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    ) ??
    false;
