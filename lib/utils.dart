import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

String tr(String key, [Map<String, String>? params]) {
  final language = languageNotifier.value;
  final value =
      translations[language]?[key] ?? translations['es']?[key] ?? key;
  if (params == null || params.isEmpty) {
    return value;
  }
  return params.entries.fold(value, (result, entry) {
    return result.replaceAll('{${entry.key}}', entry.value);
  });
}

ThemeMode themeModeFromString(String? value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode mode) {
  return mode == ThemeMode.dark
      ? 'dark'
      : mode == ThemeMode.light
      ? 'light'
      : 'system';
}

Future<void> saveLanguagePreference(String language) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', language);
}

Future<void> saveThemePreference(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('themeMode', themeModeToString(mode));
}

Future<void> clearSavedToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('access_token');
}

int? parseNumericId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final cleaned = value.trim();
    final asInt = int.tryParse(cleaned);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(cleaned);
    if (asDouble != null) return asDouble.toInt();
  }
  return null;
}

Widget buildPaymentMethodChip(
  BuildContext context,
  IconData icon,
  String text,
) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final bgColor = isDark
      ? theme.colorScheme.surfaceContainerHighest
      : theme.colorScheme.surface;
  final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);
  final contentColor = theme.colorScheme.onSurface;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: contentColor),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: contentColor,
          ),
        ),
      ],
    ),
  );
}

bool isPaymentDefault(Map<String, dynamic> method) {
  final val = method['predeterminado'] ?? method['predet'] ?? method['default'];
  if (val == null) return false;
  if (val is bool) return val;
  if (val is String) return val.toLowerCase() == 'true';
  return false;
}