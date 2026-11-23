import 'dart:convert';

import 'daily_review.dart';

import 'review_language.dart';

String _names(Iterable<Map> rows) =>
    rows.map((row) => '«${row['task']}»').join(' و');

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

  if (completions.isNotEmpty) {
    final named = _names(completions.take(3));
    final earlier = data['carriedInCompleted'] as int;
    final older =
        completions
            .where((task) => task['created'] != data['logicalDay'])
            .toList()
          ..sort(
            (a, b) =>
                (a['created'] as String).compareTo(b['created'] as String),
          );
    final oldest = older.firstOrNull;
    final since = oldest == null
        ? null
        : reviewRelativeDay(
            reviewDaysAgo(oldest['created'] as String, snapshot.day),
          );
    final opening = completed == 1 && since != null
        ? 'أغلقت اليوم $named، وهي مهمة أضفتها $since.'
        : completed <= 3
        ? 'أنجزت اليوم $named.'
        : 'من بين المهام التي أنجزتها اليوم $named.';
    paragraph(opening, [
      if (completed > 1 && oldest != null)
        'كانت «${oldest['task']}» مفتوحة منذ أن أضفتها $since${earlier < completed ? '، فجمعت اليوم بين إنهاء عمل سابق وإنجاز مهام جديدة' : ''}.',
      for (final project in projects.where(
        (p) => (p['done'] as int) >= 2 && p['done'] * 2 > completed,
      ))
        'تركّز ما أنهيته اليوم بالدرجة الأولى في «${project['tag']}»${project['nextTask'] == null ? '.' : '، وما زال لهذا العمل امتداد في قائمة اليوم.'}',
      if (focus == 0 && data['timeTrackingEnabledNow'] == true)
        'يظهر أثر عملك اليوم في المهام المكتملة، حتى مع غياب جلسات تركيز مسجّلة.',
    ]);
  }

  if (focus > 0 && focused.isNotEmpty) {
    final top = focused.first;
    final topMinutes = top['minutes'] as int;
    final title = '«${top['task']}»';
    final closedTime = data['focusOnCompletedToday'] as int;
    final openTime = data['focusOnOpenTasks'] as int;
    final openTask = focused.where((t) => t['open'] == true).firstOrNull;
    final ongoing = openTask == null
        ? 'لأعمال ما زالت قيد التنفيذ'
        : openTask['minutes'] == openTime
        ? 'لمهمة «${openTask['task']}» التي ما زالت مفتوحة'
        : 'لأعمال ما زالت مفتوحة، منها «${openTask['task']}»';
    final opening = topMinutes == focus
        ? 'خصّصت ${reviewDuration(focus)} من التركيز لمهمة $title.'
        : topMinutes * 3 >= focus * 2
        ? 'استأثرت $title بمعظم تركيزك اليوم. خصّصت لها ${reviewDuration(topMinutes)} من أصل ${reviewDuration(focus)}.'
        : 'توزّع تركيزك اليوم على أكثر من مهمة خلال ${reviewDuration(focus)}، منها $title.';
    paragraph(opening, [
      if (openTime > 0 && closedTime > 0)
        if (openTime * 3 >= focus * 2)
          'ذهب معظم هذا الوقت إلى عمل ما زال مفتوحًا، لذا تُظهر قائمة الإنجازات جزءًا فقط مما عملت عليه اليوم.'
        else if (closedTime * 3 >= focus * 2)
          'ذهب معظم هذا الوقت إلى مهام أغلقتها اليوم، وخصّصت ${reviewDuration(openTime)} $ongoing.'
        else
          'جمعت جلساتك بين إنهاء أعمال ومواصلة مهام مفتوحة، فظهر أثر التركيز في جانبي قائمة اليوم.'
      else if (openTime == focus && completed > 0)
        'جاءت إنجازاتك اليوم من مهام أخرى، بينما ذهب وقت التركيز المسجّل إلى عمل ما زال مفتوحًا.'
      else if (openTime == focus && sessions > 1)
        'عدت خلال جلسات اليوم إلى أعمال ما زالت قيد التنفيذ. يفيد سجل التركيز هنا في تتبّع تقدم لا يظهر بعد في قائمة الإنجازات.'
      else if (closedTime == focus && top['completedToday'] == true)
        'أغلقت $title اليوم، فاجتمع فيها التركيز المسجّل والإنجاز.',
      if (sessions == 1 && completed == 0 && notes == 0 && manual == 0)
        'هذه جلسة واحدة حتى الآن، وما زال من المبكر استخلاص نمط لليوم.',
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
  for (final tag in rows('priorWorkForActiveTags')) {
    final last = tag['lastWorkDayInWindow'] as String?;
    if (last == null || tag['workedToday'] != true) continue;
    final gap = reviewDaysAgo(last, snapshot.day);
    if (gap >= 3) {
      progress.add(
        'استأنفت اليوم العمل على «${tag['tag']}». كان آخر إنجاز أو وقت عمل سجّلته تحت هذا الوسم ${reviewRelativeDay(gap)}.',
      );
    }
  }
  // Keep a note tied to the specific open task it can help the user resume.
  final noted = pending.where((p) => p['latestNoteToday'] != null).firstOrNull;
  if (progress.isEmpty && noted == null) {
    final event = events
        .where(
          (e) =>
              e['event'] == 'note' &&
              (e['excerpt'] as String? ?? '').isNotEmpty,
        )
        .firstOrNull;
    if (event != null) {
      progress.add(
        'دوّنت اليوم في «${event['task']}» ما وصلت إليه بقولك «${event['excerpt']}».',
      );
    }
  }
  if (manual > 0 && (focus == 0 || progress.isEmpty)) {
    final event = events.where((e) => e['event'] == 'manual').firstOrNull;
    if (focus == 0 || event != null) {
      progress.add(
        event == null
            ? 'يظهر العمل اليوم أيضًا في الوقت الذي أضفته يدويًا، وقد بلغ ${reviewDuration(manual)}.'
            : 'يظهر جانب من عملك على «${event['task']}» في الوقت المضاف يدويًا. سجّلت لها ${reviewDuration(event['minutes'] as int)} بهذه الطريقة.',
      );
    }
  }
  if (progress.isNotEmpty) paragraph(progress.first, progress.skip(1));

  if (sections.isEmpty && noted == null) {
    final plan = events.where((e) => e['event'] == 'created').take(2);
    paragraph(
      created > 0 && focus == 0 && manual == 0 && notes == 0
          ? 'ما سجلته حتى الآن يتعلق بتخطيط العمل${plan.isEmpty ? '' : '، ومنه إضافة ${_names(plan)}'}.'
          : 'ما زالت شواهد التنفيذ اليوم محدودة.',
      ['السجل محدود للحكم على سير التنفيذ حتى الآن.'],
    );
  }
  final project = projects.where((p) => p['nextTask'] != null).firstOrNull;
  final pinned = pending.where((p) => p['pinned'] == true).firstOrNull;
  if (noted != null) {
    paragraph(
      'تبقى «${noted['task']}» مفتوحة. كتبت فيها اليوم «${noted['latestNoteToday']}».',
      ['يمكنك الرجوع إلى هذه الملاحظة لتحديد نقطة البداية عند استئناف المهمة.'],
    );
    if (sections.length > 1) sections.last['next'] = true;
  } else if (project != null) {
    paragraph(
      'بعد ما أنجزته اليوم في «${project['tag']}»، تبقى «${project['nextTask']}» ضمن أعمال اليوم تحت الوسم نفسه.',
      ['إذا أردت مواصلة العمل تحت هذا الوسم، فهذه نقطة بداية للجلسة التالية.'],
    );
    sections.last['next'] = true;
  } else if (pinned != null && focus > 0 && pinned['focusToday'] == null) {
    paragraph(
      'تظل «${pinned['task']}» مثبّتة في قائمة اليوم، بينما ذهبت جلسات التركيز المسجّلة إلى مهام أخرى.',
      ['قبل الجلسة التالية، راجع ما إذا كانت ما تزال الأولى باهتمامك.'],
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
    'دقائق التركيز حسب الوسم اليوم': data['topFocusMinutesTodayByTag'],
    'أمثلة من أحداث اليوم': events.take(4).toList(),
    'أمثلة من الأيام السابقة': rows('historicalExamples').take(3).toList(),
    'sections': sections,
  });
}
