import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

// --- ENTRY POINT ---
void main() => runApp(const MyApp());

// --- ROOT APP ---
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = false;
  final SettingsStorage _settingsStorage = SettingsStorage();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    bool savedTheme = await _settingsStorage.readDarkMode();
    if (!mounted) return;
    setState(() {
      _isDark = savedTheme;
    });
  }

  void _onThemeToggle(bool value) {
    setState(() {
      _isDark = value;
    });
    _settingsStorage.writeDarkMode(value);
  }

  // --- THEME CONFIGURATION ---
  ThemeData _getNothingTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD71921), // Nothing Red
        surface: Colors.black,
        onSurface: Colors.white,
        secondary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1.5),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFFD71921),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD71921), width: 2)),
        labelStyle: const TextStyle(color: Colors.grey),
      ),
      dividerTheme: const DividerThemeData(color: Colors.white24, thickness: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledger App',
      theme: _isDark ? _getNothingTheme() : ThemeData.light(),
      home: LedgerHome(isDark: _isDark, onThemeChanged: _onThemeToggle),
    );
  }
}
