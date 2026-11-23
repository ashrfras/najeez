// Relative dates in a saved review are relative to its logical day.
int reviewDaysAgo(String dayKey, DateTime reviewDay) {
  final date = DateTime.parse(dayKey);
  return DateTime.utc(
    reviewDay.year,
    reviewDay.month,
    reviewDay.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
}

String reviewRelativeDay(int days) {
  const recent = [
    'اليوم',
    'أمس',
    'قبل يومين',
    'قبل ثلاثة أيام',
    'قبل أربعة أيام',
    'قبل خمسة أيام',
  ];
  if (days < recent.length) return recent[days];
  if (days <= 9) return days == 7 ? 'قبل أسبوع' : 'قبل حوالي أسبوع';
  if (days <= 11) return 'قبل نحو عشرة أيام';
  if (days <= 17) return days == 14 ? 'قبل أسبوعين' : 'قبل حوالي أسبوعين';
  if (days <= 24) {
    return days == 21 ? 'قبل ثلاثة أسابيع' : 'قبل حوالي ثلاثة أسابيع';
  }
  if (days <= 35) return 'قبل حوالي شهر';
  if (days <= 45) return 'قبل نحو ستة أسابيع';
  final months = (days / 30.44).round();
  if (months == 2) return 'قبل حوالي شهرين';
  if (months == 11) return 'قبل نحو أحد عشر شهرًا';
  if (months < 11) return 'قبل نحو $months أشهر';
  if (months < 15) return 'قبل حوالي سنة';
  if (months <= 21) return 'قبل نحو سنة ونصف';
  final years = (days / 365.25).round();
  if (years == 2) return 'قبل حوالي سنتين';
  return years <= 10 ? 'قبل نحو $years سنوات' : 'قبل نحو $years سنة';
}

String reviewDuration(num minutes) {
  if (minutes < 1) return 'أقل من دقيقة';
  // Keep short sessions distinct. For longer work, use familiar clock fractions.
  final int rounded;
  if (minutes < 10) {
    rounded = minutes.round();
  } else if (minutes < 60) {
    rounded = (minutes / 5).round() * 5;
  } else {
    rounded = (minutes / 15).round() * 15;
  }
  final hours = rounded ~/ 60;
  final remainder = rounded % 60;
  final String label;
  if (hours == 0) {
    label = switch (remainder) {
      1 => 'دقيقة واحدة',
      2 => 'دقيقتين',
      3 => 'ثلاث دقائق',
      4 => 'أربع دقائق',
      5 => 'خمس دقائق',
      6 => 'ست دقائق',
      7 => 'سبع دقائق',
      8 => 'ثماني دقائق',
      9 => 'تسع دقائق',
      10 => 'عشر دقائق',
      15 => 'ربع ساعة',
      20 => 'ثلث ساعة',
      30 => 'نصف ساعة',
      45 => 'ثلاثة أرباع الساعة',
      50 => 'ساعة إلا عشر دقائق',
      55 => 'ساعة إلا خمس دقائق',
      _ => '$remainder دقيقة',
    };
  } else {
    final whole = hours == 1
        ? 'ساعة'
        : hours == 2
        ? 'ساعتين'
        : hours <= 10
        ? '$hours ساعات'
        : '$hours ساعة';
    label =
        whole +
        switch (remainder) {
          15 => ' وربع',
          30 => ' ونصف',
          45 => ' وثلاثة أرباع',
          _ => '',
        };
  }
  return minutes == rounded ? label : 'حوالي $label';
}
