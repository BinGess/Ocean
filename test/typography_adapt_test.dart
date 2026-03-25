import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/theme/app_typography.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/widgets/daily_mood_picker.dart';

Widget _buildLocalizedApp({
  required Widget child,
  Locale locale = const Locale('en'),
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, app) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: app!,
      );
    },
    home: Scaffold(body: child),
  );
}

void main() {
  test('body typography keeps readable minimum size and wired font families',
      () {
    expect(AppTypography.bodyPrimary.fontSize, greaterThanOrEqualTo(16));
    expect(AppTypography.bodySecondary.fontSize, greaterThanOrEqualTo(16));
    expect(AppTypography.modalBody.fontSize, greaterThanOrEqualTo(16));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    final hasDeclaredFonts =
        RegExp(r'^\s+fonts:\s*$', multiLine: true).hasMatch(pubspec);

    if (!hasDeclaredFonts) {
      expect(AppTypography.sansFamily.startsWith('Noto'), isFalse);
      expect(AppTypography.serifFamily.startsWith('Noto'), isFalse);
    }
  });

  testWidgets('DailyMoodPicker stays stable on compact screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildLocalizedApp(
        locale: const Locale('en'),
        textScaleFactor: 1.8,
        child: const DailyMoodPicker(onSelect: _noopSelect),
      ),
    );
    await tester.pump();

    expect(find.text('How are you feeling today?'), findsOneWidget);
    expect(find.text('Choose a mood to capture today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noopSelect(DailyMood _) {}
