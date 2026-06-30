import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageSelectionDialog extends StatelessWidget {
  const LanguageSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('change_language'.tr()), // Texte traduit
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('English'),
            onTap: () {
              context.setLocale(Locale('en', 'US'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('Français'),
            onTap: () {
              context.setLocale(Locale('fr', 'FR'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text('العربية'),
            onTap: () {
              context.setLocale(Locale('ar', 'TN'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
