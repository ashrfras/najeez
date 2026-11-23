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

// Keep whole noun phrases from the title. A topic introduced by "بشأن" can
// identify the work more precisely than the object of an action such as "إرسال".
List<String> reviewTaskTopics(String title, {String project = ''}) {
  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[ـً-ْٰ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .trim();
  final normalized = normalize(title);
  final words = title.trim().split(RegExp(r'\s+'));
  final topics = <String>{};
  final marker = RegExp(r'^(?:بشان|بخصوص|حول|عن|regarding|about)$');
  final action = RegExp(
    r'^(?:ال)?(?:مراجعة|تدقيق|تنقيح|فحص|تحليل|اختبار|تعديل|تحديث|اصلاح|حل|اعداد|اعادة|كتابة|صياغة|تحرير|قراءة|دراسة|تصميم|تطوير|برمجة|تنفيذ|انشاء|متابعة|تنظيم|ترتيب|تجهيز|ارسال|تسليم|شراء|حجز|تلخيص|ترجمة|راجع|اكتب|صمم|جهز|ارسل|اصلح|رتب|اقرا)$'
    r'|^(?:review|write|draft|design|fix|update|prepare|send|test|edit|implement|check)$',
  );
  final boundary = RegExp(
    r'^(?:مع|في|على|عن|الى|من|ثم|حتى|قبل|بعد|عند|ضمن|بين|حسب|اليوم|غدا|لكي|بهدف|خلال|وذلك|الذي|التي|with|before|after|for|to|by|and|in)$'
    r'|^(?:للتاكد|لمعرفة|لتحديد|واعادة|وارسال|ومراجعة|وتنسيق|واضافة)',
  );
  void candidate(int start) {
    final phrase = <String>[];
    for (final word in words.skip(start)) {
      final parts = word.split(RegExp(r'[^\p{L}\p{M}\p{N}-]', unicode: true));
      final token = parts.first;
      final key = normalize(token);
      if (key.isEmpty || boundary.hasMatch(key) || marker.hasMatch(key)) break;
      phrase.add(token);
      if (phrase.length > 4) return;
      if (parts.length > 1) break;
    }
    final text = phrase.join(' ');
    final key = normalize(text);
    if (text.length < 2 ||
        text.length > 38 ||
        key == normalized ||
        key == normalize(project) ||
        !RegExp(r'\p{L}', unicode: true).hasMatch(text)) {
      return;
    }
    if (RegExp(
      r'^(?:المهمة|مهمة|العمل|عمل|تفاصيل|كل شيء|هذا|ذلك|the|a|an)$',
    ).hasMatch(key)) {
      return;
    }
    topics.add(text);
  }

  for (var i = 0; i < words.length - 1; i++) {
    if (marker.hasMatch(normalize(words[i]))) candidate(i + 1);
  }
  if (words.length > 1 && action.hasMatch(normalize(words.first))) {
    candidate(1);
  } else if (words.length > 1) {
    // A nominal heading before a separator is often already a clear subject.
    // Require a boundary so an arbitrary short title cannot be echoed whole.
    final first = normalize(words.first);
    if (first.startsWith('ال') ||
        RegExp(
          r'^(?:صفحة|شاشة|خطة|مسودة|تقرير|ملف|مشكلة|موعد|ميزانية|مقالة|فاتورة|وثيقة)$',
        ).hasMatch(first)) {
      candidate(0);
    }
  }
  return topics.take(3).toList();
}
