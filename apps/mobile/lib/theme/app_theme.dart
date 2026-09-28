import 'package:flutter/material.dart';

const ink = Color(0xff18323a);
const muted = Color(0xff718087);
const cream = Color(0xfff7f4ed);
const paper = Color(0xfffffdf8);
const teal = Color(0xff2c7775);
const coral = Color(0xffe1715d);
const line = Color(0xffe2e0d8);

ThemeData appTheme() => ThemeData(
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: teal),
      fontFamily: 'sans',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
      ),
    );