import 'package:flutter/material.dart';

Future<void> showAdHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Having trouble loading an ad?'),
    scrollable: true,
    content: const Text(
      'Ads need an internet connection. Network filtering, a VPN or an ad blocker may prevent them from loading. The same error can have other causes.\n\nIf you want to try an ad, switch between Wi-Fi and mobile data. If you use a custom Private DNS provider, you can search for Private DNS in phone Settings and choose Automatic, then return and retry.\n\nYour settings are your choice. You can keep them and wait for free lives, use earned coins or play Classic, Sprint and Daily Challenge without lives. T-BLOCK does not change your DNS settings.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Continue playing'),
      ),
    ],
  ),
);
