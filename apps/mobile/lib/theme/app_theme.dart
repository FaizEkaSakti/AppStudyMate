import 'package:flutter/material.dart';

const ink = Color(0xff1a302b);
const muted = Color(0xff6d7d76);
const cream = Color(0xfff2f5ef);
const paper = Color(0xffffffff);
const teal = Color(0xff20594c);
const coral = Color(0xffd66c59);
const leaf = Color(0xffa8c987);
const gold = Color(0xffe8b451);
const line = Color(0xffdce5dc);

ThemeData appTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: teal,
    brightness: Brightness.light,
  ).copyWith(
    primary: teal,
    secondary: coral,
    tertiary: gold,
    surface: paper,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: cream,
    fontFamily: 'Aptos',
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      foregroundColor: ink,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: leaf.withValues(alpha: 0.35),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected) ? teal : muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          )),
    ),
  );
}