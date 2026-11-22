const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];
const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String arabicWeekday(DateTime date) => _weekdays[date.weekday - 1];
String arabicDayMonth(DateTime date) =>
    '${date.day} ${_months[date.month - 1]}';

String arabicDate(DateTime date) =>
    '${arabicWeekday(date)}، ${arabicDayMonth(date)}';

String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
