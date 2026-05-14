import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

String formatRecordDateTime(DateTime dateTime) {
  final month = dateTime.month;
  final day = dateTime.day;
  final period = dateTime.hour < 12 ? '上午' : '下午';
  final hour24 = dateTime.hour;
  final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$month月$day日·$period$hour:$minute';
}

Future<DateTime?> showRecordDateTimePicker({
  required BuildContext context,
  required DateTime initialDateTime,
}) {
  final minimumDate = DateTime(2000);
  final maximumDate = DateTime.now().add(const Duration(days: 3650));
  final safeInitialDateTime = _clampDateTime(
    initialDateTime,
    minimumDate,
    maximumDate,
  );

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) {
      return _RecordDateTimePickerSheet(
        initialDateTime: safeInitialDateTime,
        minimumDate: minimumDate,
        maximumDate: maximumDate,
      );
    },
  );
}

DateTime _clampDateTime(
  DateTime value,
  DateTime minimumDate,
  DateTime maximumDate,
) {
  if (value.isBefore(minimumDate)) {
    return minimumDate;
  }
  if (value.isAfter(maximumDate)) {
    return maximumDate;
  }
  return value;
}

class _RecordDateTimePickerSheet extends StatefulWidget {
  final DateTime initialDateTime;
  final DateTime minimumDate;
  final DateTime maximumDate;

  const _RecordDateTimePickerSheet({
    required this.initialDateTime,
    required this.minimumDate,
    required this.maximumDate,
  });

  @override
  State<_RecordDateTimePickerSheet> createState() =>
      _RecordDateTimePickerSheetState();
}

class _RecordDateTimePickerSheetState
    extends State<_RecordDateTimePickerSheet> {
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.initialDateTime;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 344,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '保存日期',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    onPressed: () =>
                        Navigator.of(context).pop(_selectedDateTime),
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: _selectedDateTime,
                minimumDate: widget.minimumDate,
                maximumDate: widget.maximumDate,
                minuteInterval: 1,
                use24hFormat: false,
                onDateTimeChanged: (value) {
                  _selectedDateTime = value;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
