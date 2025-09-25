import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showAttendanceDialog(
  BuildContext context, {
  required String actionLabel,
  String? happenedAtIso,
  String? location,
}) async {
  final normalized = actionLabel.toLowerCase();
  final isCheckIn = normalized.contains('in') && !normalized.contains('out');
  final friendlyAction = isCheckIn ? 'Check-In' : 'Check-Out';

  DateTime? parsed;
  if (happenedAtIso != null && happenedAtIso.isNotEmpty) {
    parsed = DateTime.tryParse(happenedAtIso)?.toLocal();
  }
  final formattedTime = parsed != null
      ? '${DateFormat('EEE, MMM d').format(parsed)} at ${DateFormat('h:mm a').format(parsed)}'
      : 'Just now';

  final summaryLines = [
    'Recorded at $formattedTime',
    if (location != null && location.isNotEmpty) 'Location: $location',
  ];

  final desc = summaryLines.join('\n');
  final theme = Theme.of(context);

  await AwesomeDialog(
    context: context,
    dialogType: isCheckIn ? DialogType.success : DialogType.infoReverse,
    animType: AnimType.bottomSlide,
    headerAnimationLoop: false,
    title: friendlyAction,
    titleTextStyle:
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    desc: desc,
    descTextStyle: theme.textTheme.bodyMedium,
    buttonsTextStyle: theme.textTheme.labelLarge,
    btnOkColor: theme.colorScheme.primary,
    btnOkText: 'Done',
    btnOkOnPress: () {},
  ).show();
}
