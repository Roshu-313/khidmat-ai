// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() => runApp(const KhidmatApp());

class KhidmatApp extends StatelessWidget {
  const KhidmatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khidmat AI',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
      ),
      home: const HomeScreen(),
    );
  }
}