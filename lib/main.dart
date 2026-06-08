import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'utils.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  languageNotifier.value = prefs.getString('language') ?? 'es';
  themeModeNotifier.value = themeModeFromString(prefs.getString('themeMode'));
  runApp(const DesktopLoginApp());
}

class DesktopLoginApp extends StatelessWidget {
  const DesktopLoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: languageNotifier,
          builder: (context, language, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: tr('appTitle'),
              locale: Locale(language),
              supportedLocales: const [Locale('es'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              themeMode: themeMode,
              home: const LoginScreen(),
            );
          },
        );
      },
    );
  }
}
