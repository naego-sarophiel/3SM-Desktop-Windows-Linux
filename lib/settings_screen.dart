import 'constants.dart';
import 'package:flutter/material.dart';
import 'utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _currentLanguage;
  late ThemeMode _currentThemeMode;

  @override
  void initState() {
    super.initState();
    _currentLanguage = languageNotifier.value;
    _currentThemeMode = themeModeNotifier.value;
  }

  void _changeLanguage(String language) {
    setState(() {
      _currentLanguage = language;
    });
    languageNotifier.value = language;
    saveLanguagePreference(language);
  }

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _currentThemeMode = mode;
    });
    themeModeNotifier.value = mode;
    saveThemePreference(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('language'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(tr('spanish')),
                    trailing: _currentLanguage == 'es'
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => _changeLanguage('es'),
                  ),
                  ListTile(
                    title: Text(tr('english')),
                    trailing: _currentLanguage == 'en'
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => _changeLanguage('en'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(tr('theme'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(tr('light')),
                    trailing: _currentThemeMode == ThemeMode.light
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => _changeTheme(ThemeMode.light),
                  ),
                  ListTile(
                    title: Text(tr('dark')),
                    trailing: _currentThemeMode == ThemeMode.dark
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => _changeTheme(ThemeMode.dark),
                  ),
                  ListTile(
                    title: Text(tr('system')),
                    trailing: _currentThemeMode == ThemeMode.system
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => _changeTheme(ThemeMode.system),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}