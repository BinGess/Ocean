import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

String formatRecordDateTime(
  DateTime dateTime, {
  String languageCode = 'zh',
}) {
  // 服务端返回 UTC DateTime（isUtc=true），列表用 DateFormat.format(time.toLocal())
  // 而这里直接取 .hour 会读到 UTC 小时值（对中国用户差 8 小时）。
  // 在入口统一转为本地时间，和列表的处理方式保持一致。
  final local = dateTime.toLocal();
  final month = local.month;
  final day = local.day;
  final hour24 = local.hour;
  final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final minute = local.minute.toString().padLeft(2, '0');

  if (languageCode == 'en') {
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${_englishMonthName(month)} $day · $hour:$minute $period';
  }

  final period = local.hour < 12 ? '上午' : '下午';
  return '$month月$day日·$period$hour:$minute';
}

String _englishMonthName(int month) {
  return const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
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
    final l10n = AppLocalizations.of(context) ??
        AppLocalizations(Localizations.localeOf(context));

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
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.recordSaveDate,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                    child: Text(
                      l10n.confirm,
                      style: const TextStyle(
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
                use24hFormat:
                    Localizations.localeOf(context).languageCode != 'en',
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
