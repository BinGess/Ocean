import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/l10n/app_localizations.dart';
import 'package:mindflow/presentation/widgets/daily_mood_picker.dart';
import 'package:mindflow/presentation/widgets/record_button.dart';

Widget _buildLocalizedApp({
  required Widget child,
  Locale locale = const Locale('en'),
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
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('RecordButton uses localized English copy and semantics',
      (tester) async {
    await tester.pumpWidget(
      _buildLocalizedApp(
        child: const RecordButton(mode: RecordButtonMode.press),
      ),
    );
    await tester.pump();

    expect(find.text('Hold to speak'), findsOneWidget);
    expect(find.text('长按录音'), findsNothing);

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(RecordButton)),
      matchesSemantics(
        label: 'Hold to speak',
        hint: 'Double tap and hold to start recording',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasLongPressAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('DailyMoodPicker uses localized English title and mood labels',
      (tester) async {
    await tester.pumpWidget(
      _buildLocalizedApp(
        child: DailyMoodPicker(
          onSelect: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling today?'), findsOneWidget);
    expect(find.text('Choose a mood to capture today'), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('开心'), findsNothing);
  });
}
