import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:vagina/l10n/app_localizations.dart';

String formatSessionDateTime(BuildContext context, DateTime value) {
  final locale = AppLocalizations.of(context).localeName;
  return DateFormat.yMd(locale).add_Hms().format(value);
}

String formatSessionDuration(BuildContext context, int seconds) {
  final l10n = AppLocalizations.of(context);
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return l10n.sessionDetailDurationValue(minutes, remainingSeconds);
}
