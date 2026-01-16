/// Utility for formatting durations and timestamps
class DurationFormatter {
  const DurationFormatter._();

  /// Format seconds as MM:SS
  static String formatMinutesSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format seconds as HH:MM:SS
  static String formatHoursMinutesSeconds(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Format DateTime as HH:MM:SS.mmm (for log timestamps)
  static String formatTimestamp(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}.'
        '${dateTime.millisecond.toString().padLeft(3, '0')}';
  }

  /// Format DateTime in Japanese style (YYYY年MM月DD日 HH時MM分SS秒)
  static String formatJapaneseDateTime(DateTime dateTime) {
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 '
        '${dateTime.hour}時${dateTime.minute}分${dateTime.second}秒';
  }

  /// Format DateTime as relative date (今日, 昨日, or YYYY/MM/DD)
  /// [includeTime] - whether to include time component
  static String formatRelativeDate(DateTime dateTime,
      {bool includeTime = true}) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final timeStr =
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return includeTime ? '今日 $timeStr' : '今日';
    } else if (difference.inDays == 1) {
      return includeTime ? '昨日 $timeStr' : '昨日';
    } else {
      final dateStr = '${dateTime.year}/${dateTime.month}/${dateTime.day}';
      return includeTime ? '$dateStr $timeStr' : dateStr;
    }
  }

  /// Format call duration in Japanese (X分Y秒)
  static String formatCallDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes分$secs秒';
  }

  /// Format duration as M:SS (compact format)
  static String formatDurationCompact(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
