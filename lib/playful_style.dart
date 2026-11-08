import 'package:flutter/material.dart';

import 'customization.dart';

const buddyCream = Color(0xFFFFFBF4);
const buddyInk = Color(0xFF41255F);
const buddyMuted = Color(0xFF695775);
const buddyPink = Color(0xFFB32972);
const buddyGold = Color(0xFFA76100);

ThemeData buddyTheme(GamePalette palette) => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: palette.background.first,
  colorScheme: ColorScheme.fromSeed(
    seedColor: buddyPink,
    brightness: Brightness.light,
    surface: buddyCream,
    onSurface: buddyInk,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: buddyInk,
    displayColor: buddyInk,
    fontFamily: 'Roboto',
  ),
  iconTheme: const IconThemeData(color: buddyInk),
  appBarTheme: const AppBarTheme(
    backgroundColor: buddyCream,
    foregroundColor: buddyInk,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      fontFamily: 'Roboto',
      color: buddyInk,
      fontSize: 21,
      fontWeight: FontWeight.w800,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: buddyCream,
    indicatorColor: buddyPink.withValues(alpha: .13),
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(color: buddyInk, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  ),
  cardTheme: const CardThemeData(color: buddyCream, elevation: 0),
  dialogTheme: DialogThemeData(
    backgroundColor: buddyCream,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: buddyCream,
    surfaceTintColor: Colors.transparent,
  ),
  sliderTheme: SliderThemeData(
    trackHeight: 5,
    activeTrackColor: buddyPink,
    inactiveTrackColor: buddyPink.withValues(alpha: .16),
    thumbColor: buddyPink,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
  ),
);
