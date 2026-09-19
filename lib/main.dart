import 'package:flutter/material.dart';

import 'views/form_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VistecApp());
}

class VistecApp extends StatelessWidget {
  const VistecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISTE • Relevamiento de Información',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const FormScreen(),
    );
  }
}
