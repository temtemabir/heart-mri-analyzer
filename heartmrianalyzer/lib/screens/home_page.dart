import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_rounded,
                color: Colors.red,
                size: 100,
              ),
              SizedBox(height: 20),
              Text(
                'choose_language'.tr(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              SizedBox(height: 40),
              // Option for English
              LanguageButton(
                onPressed: () {
                  context.setLocale(Locale('en', 'US')); // Set English language
                  Navigator.pushNamed(context, '/login'); // Go to login page
                },
                text: 'English',
                icon: Icons.language,
              ),
              SizedBox(height: 10),
              // Option for French
              LanguageButton(
                onPressed: () {
                  context.setLocale(Locale('fr', 'FR')); // Set French language
                  Navigator.pushNamed(context, '/login'); // Go to login page
                },
                text: 'Français',
                icon: Icons.language,
              ),
              SizedBox(height: 10),
              // Option for Arabic
              LanguageButton(
                onPressed: () {
                  context.setLocale(Locale('ar', 'TN')); // Set Arabic language
                  Navigator.pushNamed(context, '/login'); // Go to login page
                },
                text: 'العربية',
                icon: Icons.language,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final IconData icon;

  const LanguageButton({super.key, 
    required this.onPressed,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: Colors.white,
      ),
      label: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, backgroundColor: Colors.red.shade600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  }
}
