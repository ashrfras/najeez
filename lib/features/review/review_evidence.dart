import 'dart:convert';

import 'daily_review.dart';

import 'review_language.dart';

/// Each paragraph has a factual opening and complementary readings of the
/// same evidence. The model selects the interpretation within each topic.
String qwenEvidence(ReviewSnapshot snapshot) {
  final data = snapshot.payload;
  final history = Map<String, dynamic>.from(data['dailyTotals'] as Map);
  final today = (history.remove(data['logicalDay']) as List).cast<int>();
  final [created, completed, sessions, focus, manual, notes] = today;
  List<Map> rows(String key) => (data[key] as List).cast<Map>();
  final completions = rows('completedTodayExamples');
  final focused = rows('focusOutcomesToday');
  final events = rows('todayExamples');
  final pending = rows('pendingTodayExamples');
  final projects = rows('projectCompletions');
  final sections = <Map<String, Object>>[];
  void paragraph(String opening, Iterable<String> interpretations) {
    sections.add({
      'opening': opening,
      'readings': interpretations.toSet().take(6).toList(),
    });
  }

  // Wording is selected by Qwen from broad work types. Titles are evidence
  // for that decision and are never substituted into the displayed review.
  final subjects = <Map<String, String>>[];
  int subject(Map row) {
    final item = {
      'title': row['task'] as String,
      'project': (row['tag'] as String? ?? '').trim(),
    };
    final found = subjects.indexWhere(
      (s) => s['title'] == item['title'] && s['project'] == item['project'],
    );
    if (found >= 0) return found;
    subjects.add(item);
    return subjects.length - 1;
  }

  String area(Map row) {
    final project = (row['tag'] as String? ?? '').trim();
    return project.isEmpty ? '{work${subject(row)}}' : 'مشروع «$project»';
  }

  String inArea(Map row) => (row['tag'] as String? ?? '').trim().isEmpty
      ? '{in${subject(row)}}'
      : ' في ${area(row)}';

  String step(Map row) => '{step${subject(row)}}';

  if (completions.isNotEmpty) {
    final older =
        completions.where((t) => t['created'] != data['logicalDay']).toList()
          ..sort(
            (a, b) =>
                (a['created'] as String).compareTo(b['created'] as String),
          );
    final work = older.firstOrNull ?? completions.first;
    final since = reviewRelativeDay(
      reviewDaysAgo(work['created'] as String, snapshot.day),
    );
    paragraph(
      older.isNotEmpty
          ? 'أنهيت اليوم خطوة${inArea(work)} كنت قد خطّطت لها $since.'
          : 'حوّلت اليوم ما خطّطت له${inArea(work)} إلى عمل مكتمل.',
      [
        if (older.isNotEmpty && (data['carriedInCompleted'] as int) < completed)
          'جمعت بين إتمام ما كان معلّقًا وفتح المجال للعمل الجديد الذي أنجزته اليوم أيضًا.',
        if (focus == 0 && data['timeTrackingEnabledNow'] == true)
          'حتى من دون جلسة تركيز مسجّلة، لديك نتيجة ملموسة ترجع إليها عند اختيار ما يليها.',
      ],
    );
  }
  if (focus > 0 && focused.isNotEmpty) {
    final top = focused.first;
    final minutes = top['minutes'] as int;
    final closedTime = data['focusOnCompletedToday'] as int;
    final openTime = data['focusOnOpenTasks'] as int;
    final opening = minutes == focus
        ? 'منحت ${area(top)} ${reviewDuration(focus)} من التركيز اليوم.'
        : minutes * 3 >= focus * 2
        ? 'كان النصيب الأكبر من تركيزك اليوم في ${area(top)}، حيث قضيت ${reviewDuration(minutes)} من أصل ${reviewDuration(focus)}.'
        : 'وزّعت ${reviewDuration(focus)} من التركيز بين أكثر من مهمة اليوم، وكان من بينها عمل في ${area(top)}.';
    paragraph(opening, [
      if (openTime > 0 && closedTime > 0)
        if (closedTime * 3 >= focus * 2)
          'ذهب معظم هذا الوقت إلى مهام أغلقتها، وخصّصت ${reviewDuration(openTime)} لعمل ما زال مفتوحًا.'
        else if (openTime * 3 >= focus * 2)
          'ذهب معظم هذا الجهد إلى أعمال ما زلت تتابعها، فعدد المهام المكتملة وحده لا يُظهر كل ما عملت عليه.'
        else
          'جزء من هذا الوقت أثمر إنجازًا اليوم، وجزء آخر أعطاك نقطة يمكنك أن تواصل منها.',
      if (openTime == focus && completed > 0)
        'أنجزت أعمالًا أخرى اليوم أيضًا، بينما بقيت المهام التي ركّزت عليها مفتوحة.',
      if (closedTime == focus && top['completedToday'] == true)
        'اكتمل اليوم العمل الذي خصّصت له هذا الوقت.',
      if (sessions == 1 && completed == 0 && notes == 0 && manual == 0)
        'هذه جلسة واحدة حتى الآن. إن أردت تسهيل العودة إليها، دوّن أين توقّفت بينما التفاصيل حاضرة.',
    ]);

    // Compare like with like: prior active days at the same logical-day cutoff.
    // Skip ordinary variation, sparse history, and differences lost in rounding.
    final prior = (data['priorActiveDayFocusBySameTime'] as List).cast<int>();
    if (prior.length >= 4) {
      final middle = prior.length ~/ 2;
      final median = prior.length.isOdd
          ? prior[middle]
          : (prior[middle - 1] + prior[middle]) / 2;
      final delta = focus - median;
      final outsideMiddleHalf =
          focus < prior[(prior.length - 1) ~/ 4] ||
          focus > prior[((prior.length - 1) * 3 / 4).ceil()];
      if (outsideMiddleHalf &&
          delta.abs() >= 15 &&
          delta.abs() >= median * .25) {
        final direction = delta > 0 ? 'أكثر' : 'أقل';
        sections.last['context'] =
            'سجّلت اليوم وقت تركيز $direction مما تسجّله عادةً حتى هذه الساعة في أيام التركيز السابقة. الفارق ${reviewDuration(delta.abs())}.';
      }
    }
  }

  final progress = <String>[];
  for (final project in rows('priorWorkForActiveTags')) {
    final last = project['lastWorkDayInWindow'] as String?;
    if (last == null || project['workedToday'] != true) continue;
    final gap = reviewDaysAgo(last, snapshot.day);
    if (gap >= 3) {
      progress.add(
        'عدت اليوم إلى مشروع «${project['tag']}» بعد أن كان آخر عمل مسجّل فيه ${reviewRelativeDay(gap)}.',
      );
    }
  }
  if (manual > 0 && focus == 0) {
    final event = events.where((e) => e['event'] == 'manual').firstOrNull;
    progress.add(
      event == null
          ? 'أضفت ${reviewDuration(manual)} من العمل يدويًا اليوم.'
          : 'تظهر متابعتك في الوقت الذي أضفته يدويًا إلى ${area(event)}، ومنه ${reviewDuration(event['minutes'] as int)}.',
    );
  }
  if (progress.isNotEmpty) paragraph(progress.first, progress.skip(1));

  final quiet = completed == 0 && focus == 0 && manual == 0;
  final upcoming = rows('upcomingExamples');
  final noted = pending.where((r) => r['latestNoteToday'] != null).firstOrNull;
  final pinned = pending.where((r) => r['pinned'] == true).firstOrNull;
  final sameProject = projects.where((r) => r['nextTask'] != null).firstOrNull;
  Map? next = noted ?? pinned;
  if (next == null && sameProject != null) {
    next = {
      'task': sameProject['nextTask'],
      'tag': sameProject['tag'],
      'listNow': 'today',
    };
  }
  next ??=
      pending.where((r) => r['previousProjectWork'] != null).firstOrNull ??
      pending.firstOrNull;
  next ??= upcoming.firstOrNull;
  if (sections.isEmpty) {
    paragraph(
      notes > 0
          ? 'دوّنت اليوم ما يساعدك على تذكّر أين توقّفت. يمكنك البناء عليه عندما تعود إلى العمل.'
          : created > 0 && snapshot.hasActivity
          ? 'ما ظهر من يومك حتى الآن هو التحضير لما تريد إنجازه. اختر نتيجة صغيرة تودّ الوصول إليها في جلستك الأولى.'
          : 'ما زال سجل اليوم خفيفًا. لنأخذ ما أمامك خطوةً خطوة.',
      [],
    );
  }
  if (next != null) {
    final destination = area(next);
    final String opening;
    final note = next['latestNoteToday'] as String?;
    if (next['listNow'] == 'tomorrow') {
      opening =
          'لديك عمل مخطّط للغد${inArea(next)}. إن أحببت أن تيسّر بدايته، يكفي اليوم أن تجهّز أول ما ستحتاج إليه.';
    } else if (next['listNow'] == 'later') {
      opening =
          'لديك عمل احتفظت به لوقت لاحق${inArea(next)}. إن أحببت، حدّد الآن كيف ستبدأ واترك التنفيذ للوقت الذي يناسبك.';
    } else if (noted != null) {
      final quotable =
          note != null &&
          note.runes.length <= 55 &&
          !note.contains('\n') &&
          !note.contains(next['task'] as String) &&
          !(next['task'] as String).contains(note);
      opening = quotable
          ? 'عندما تعود إلى $destination، يمكنك البناء على ملاحظتك «$note».'
          : 'لديك نقطة جاهزة للعودة إلى $destination. افتح آخر ملاحظة كتبتها اليوم واختر منها ما تودّ متابعته.';
    } else if (pinned != null) {
      opening =
          'اخترت تثبيت عمل${inArea(next)} ضمن قائمة اليوم. إذا كان ما يزال الأهم بالنسبة إليك، فابدأ منه.';
    } else if (sameProject != null && next['tag'] == sameProject['tag']) {
      opening =
          'ما زالت أمامك خطوة في $destination. إن رغبت في مواصلة ما أنجزته فيه اليوم، يمكنك البناء عليه ما دامت تفاصيله حاضرة.';
    } else {
      opening =
          'من الخيارات المتاحة في قائمة اليوم أن تبدأ بخطوة واحدة${inArea(next)}.';
    }
    final previousWork = next['previousProjectWork'] as String?;
    if (quiet && previousWork != null && next['tag'] != null) {
      final when = reviewRelativeDay(reviewDaysAgo(previousWork, snapshot.day));
      paragraph('كنت تعمل على $destination $when. $opening', [step(next)]);
    } else {
      paragraph(opening, [step(next)]);
    }
    sections.last['next'] = true;
  } else if (quiet) {
    final recent =
        rows('priorCompletedTasks').firstOrNull ??
        rows('historicalExamples')
            .where(
              (r) =>
                  const {'completed', 'focus', 'manual'}.contains(r['event']),
            )
            .firstOrNull;
    paragraph(
      recent == null
          ? 'ما النتيجة الصغيرة التي تحب أن تكون قد أنجزتها حين تنتهي من جلستك القادمة؟'
          : 'ما عملت عليه مؤخرًا${inArea(recent)} قد يساعدك على الاختيار. هل يحتاج إلى متابعة، أم تفضّل أن تبدأ بشيء جديد؟',
      ['دوّن الخطوة التي تختارها بصيغة فعل واضح يمكنك البدء به.'],
    );
    sections.last['next'] = true;
  }
  return jsonEncode({
    'اليوم': data['logicalDay'],
    'حتى': data['asOfLocal'],
    'بداية اليوم': data['startsLocal'],
    'أعمدة النشاط':
        'مهام منشأة، منجزة، جلسات تركيز، دقائق تركيز، دقائق يدوية، ملاحظات',
    'حصيلة اليوم': today,
    'دقائق التركيز في الأيام النشطة السابقة حتى الساعة نفسها':
        data['priorActiveDayFocusBySameTime'],
    'السجل السابق': history,
    'المهام المنجزة اليوم': completions,
    'أمثلة من إنجازات سابقة': rows('priorCompletedTasks'),
    'المهام المفتوحة حسب القائمة': data['openNow'],
    'دقائق التركيز حسب المهمة اليوم': data['topFocusMinutesTodayByTask'],
    'دقائق التركيز حسب المشروع اليوم': data['topFocusMinutesTodayByTag'],
    'أمثلة من أحداث اليوم': events.take(4).toList(),
    'أمثلة من الأيام السابقة': rows('historicalExamples').take(3).toList(),
    'أعمال منتظرة': [...pending.take(2), ...upcoming.take(3)],
    'subjects': subjects,
    'sections': sections,
  });
}
