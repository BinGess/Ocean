import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/domain/entities/nvc_analysis.dart';
import 'package:mindflow/presentation/widgets/nvc_confirmation_modal.dart';

void main() {
  testWidgets('record date selector uses Cupertino date picker',
      (tester) async {
    final analyzedAt = DateTime(2026, 3, 22, 10, 30);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: NVCConfirmationModal(
            initialAnalysis: NVCAnalysis(
              observation: '刚完成一次会议',
              feelings: const [
                Feeling(
                  feeling: '疲惫',
                  intensity: IntensityLevel.medium,
                ),
              ],
              needs: const [
                Need(
                  need: '休息',
                  reason: '需要恢复精力',
                ),
              ],
              request: '先暂停十分钟',
              analyzedAt: analyzedAt,
            ),
            transcription: '刚完成一次会议，有点累。',
            onConfirm: (_, __, ___) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.expand_more_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });
}
