import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../tasks/domain/task.dart';
import '../tasks/domain/task_dates.dart';

String _dateKey(DateTime day) => day.toIso8601String().substring(0, 10);

class SavedDailyReview {
  const SavedDailyReview({
    required this.day,
    required this.asOf,
    required this.generatedAt,
    required this.signature,
    required this.text,
  });

  final DateTime day;
  final DateTime asOf;
  final DateTime generatedAt;
  final String signature;
  final String text;

  String encode() => jsonEncode({
    'day': _dateKey(day),
    'asOf': asOf.toUtc().toIso8601String(),
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'signature': signature,
    'text': text,
  });

  factory SavedDailyReview.decode(String source) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    return SavedDailyReview(
      day: DateTime.parse(value['day'] as String),
      asOf: DateTime.parse(value['asOf'] as String).toLocal(),
      generatedAt: DateTime.parse(value['generatedAt'] as String).toLocal(),
      signature: value['signature'] as String,
      text: value['text'] as String,
    );
  }
}

/// Fixed column order keeps all 28 daily totals cheap enough for a small model.
class _Totals {
  int created = 0,
      completed = 0,
      sessions = 0,
      focus = 0,
      manual = 0,
      notes = 0;
  List<int> get values => [created, completed, sessions, focus, manual, notes];
}

String _excerpt(String text, int limit) =>
    String.fromCharCodes(text.trim().runes.take(limit));

typedef _Signal = ({
  String id,
  String? tag,
  String day,
  String kind,
  int value,
  String event,
});

class ReviewSnapshot {
  ReviewSnapshot._(
    this.day,
    this.asOf,
    this.payload,
    this.signature,
    this.hasActivity,
  );

  final DateTime day;
  final DateTime asOf;
  final Map<String, Object?> payload;
  final String signature;
  final bool hasActivity;

  bool changedSince(SavedDailyReview? previous) =>
      hasActivity &&
      (previous == null ||
          previous.day != day ||
          previous.signature != signature);

  factory ReviewSnapshot.capture({
    required Iterable<Task> tasks,
    required LogicalDay logicalDay,
    required DateTime firstUse,
    required DateTime now,
    required bool timeTrackingEnabled,
  }) {
    final day = logicalDay.dayOf(now);
    final todayKey = _dateKey(day);
    final limit = DateTime(day.year, day.month, day.day - 27);
    final firstDay = logicalDay.dayOf(firstUse);
    final start = firstDay.isAfter(limit) ? firstDay : limit;
    final totals = <String, _Totals>{};
    for (
      var d = start;
      !d.isAfter(day);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      totals[_dateKey(d)] = _Totals();
    }

    final today = <Map<String, Object?>>[];
    final history = <Map<String, Object?>>[];
    final pending = <Map<String, Object?>>[];
    final signals = <_Signal>[];
    final activeIds = <String>{};
    final activeTags = <String>{};
    final previousWorkByTag = <String, _Totals>{};
    final lastWorkByTag = <String, String>{};
    int previousFocusByThisTime = 0;
    final localNow = now.toLocal();
    int dayMinute(DateTime local) =>
        (local.hour * 60 + local.minute - logicalDay.startMinutes) % 1440;
    final focusedTasks = <String, ({String title, int minutes})>{};
    final focusByTag = <String, int>{};
    final pendingTodayIds = <String>[];
    final pendingByBucket = <String, int>{};

    for (final task in tasks) {
      if (task.isDeleted || task.createdAt.isAfter(now)) continue;
      final bucket = visibleBucket(task, now, logicalDay).name;
      final completed = task.completedAt;
      final done = completed != null && !completed.isAfter(now);
      final details = {
        'task': _excerpt(task.title, 72),
        if (task.tag != null) 'tag': _excerpt(task.tag!, 36),
        'created': _dateKey(logicalDay.dayOf(task.createdAt)),
        if (task.repeatId != null) 'recurring': true,
        if (task.isPinned) 'pinned': true,
        if (done) 'completedDay': _dateKey(logicalDay.dayOf(completed)),
        if (!done) 'listNow': bucket,
        if (task.scheduledDate != null)
          'scheduled': _dateKey(task.scheduledDate!),
      };
      if (!done) {
        if (bucket == TaskBucket.today.name) pendingTodayIds.add(task.id);
        pendingByBucket.update(bucket, (v) => v + 1, ifAbsent: () => 1);
        pending.add(details);
      }

      void record(
        DateTime at,
        String kind,
        String event, {
        int minutes = 0,
        String? note,
      }) {
        if (at.isAfter(now) || at.isBefore(task.createdAt)) return;
        final key = _dateKey(logicalDay.dayOf(at));
        final total = totals[key];
        if (total == null) return;
        switch (kind) {
          case 'created':
            total.created++;
          case 'completed':
            total.completed++;
          case 'focus':
            total.sessions++;
            total.focus += minutes;
            if (key == todayKey) {
              focusedTasks[task.id] = (
                title: _excerpt(task.title, 72),
                minutes: (focusedTasks[task.id]?.minutes ?? 0) + minutes,
              );
              focusByTag.update(
                task.tag ?? 'غير مصنف',
                (v) => v + minutes,
                ifAbsent: () => minutes,
              );
            }
          case 'manual':
            total.manual += minutes;
          case 'note':
            total.notes++;
        }

        if (key != todayKey &&
            (kind == 'completed' || kind == 'focus' || kind == 'manual')) {
          final tag = task.tag;
          if (tag != null) {
            final previous = previousWorkByTag.putIfAbsent(tag, _Totals.new);
            if (kind == 'completed') previous.completed++;
            if (kind == 'focus') previous.focus += minutes;
            if (kind == 'manual') previous.manual += minutes;
            if (key.compareTo(lastWorkByTag[tag] ?? '') > 0) {
              lastWorkByTag[tag] = key;
            }
          }
          if (kind == 'focus' &&
              dayMinute(at.toLocal()) <= dayMinute(localNow)) {
            previousFocusByThisTime += minutes;
          }
        }
        final focusPrefix = 'focus:${task.id}:';
        final focusStart = kind == 'focus' && event.startsWith(focusPrefix)
            ? DateTime.tryParse(event.substring(focusPrefix.length))
            : null;
        final rows = key == todayKey ? today : history;
        rows.add({
          ...details,
          'event': kind,
          'at': at.toLocal().toIso8601String().substring(0, 16),
          if (focusStart != null)
            'startedLocal': focusStart.toLocal().toIso8601String().substring(
              0,
              16,
            ),
          if (minutes > 0) 'minutes': minutes,
          if (note != null) 'excerpt': _excerpt(note, 100),
        });
        // Automatic repeat materialization represents a plan, not new user input.
        if (kind == 'created' &&
            task.id.startsWith('daily:') &&
            task.repeatId != null) {
          return;
        }
        signals.add((
          id: task.id,
          tag: task.tag,
          day: key,
          kind: kind,
          value: minutes,
          event: event,
        ));
        if (key == todayKey) {
          activeIds.add(task.id);
          if (task.tag != null) activeTags.add(task.tag!);
        }
      }

      record(task.createdAt, 'created', task.id);
      if (done) {
        record(completed, 'completed', completed.toUtc().toIso8601String());
      }
      for (final entry in task.timeEntries) {
        if (entry.minutes > 0) {
          record(
            entry.createdAt,
            entry.id.startsWith('focus:') ? 'focus' : 'manual',
            entry.id,
            minutes: entry.minutes,
          );
        }
      }
      for (final note in task.notes) {
        record(
          note.createdAt,
          'note',
          note.id,
          note: '${note.title} ${note.text}'.trim(),
        );
      }
    }

    final material = [
      for (final id in pendingTodayIds) jsonEncode(['pendingToday', id]),
      for (final s in signals)
        if (s.day == todayKey ||
            activeIds.contains(s.id) ||
            activeTags.contains(s.tag))
          jsonEncode([s.id, s.tag, s.day, s.kind, s.value, s.event]),
    ]..sort();
    int recent(Map<String, Object?> a, Map<String, Object?> b) =>
        (b['at'] as String).compareTo(a['at'] as String);
    today.sort((a, b) {
      // Surface work evidence before planning-only activity.
      if ((a['event'] == 'created') != (b['event'] == 'created')) {
        return a['event'] == 'created' ? 1 : -1;
      }
      return recent(a, b);
    });
    history.sort((a, b) {
      if (activeTags.contains(a['tag']) != activeTags.contains(b['tag'])) {
        return activeTags.contains(a['tag']) ? -1 : 1;
      }
      return recent(a, b);
    });
    pending.sort((a, b) {
      int rank(Map<String, Object?> row) => row['pinned'] == true
          ? 0
          : row['listNow'] == 'today'
          ? 1
          : 2;
      return rank(a).compareTo(rank(b));
    });
    final tags = focusByTag.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final focused = focusedTasks.values.toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    final payload = <String, Object?>{
      'logicalDay': todayKey,
      'startsLocal': DateTime(
        day.year,
        day.month,
        day.day,
        logicalDay.hour,
        logicalDay.minute,
      ).toIso8601String(),
      'endsLocal': logicalDay.nextStart(now).toIso8601String(),
      'asOfLocal': now.toLocal().toIso8601String(),
      'windowStart': _dateKey(start),
      'timeTrackingEnabledNow': timeTrackingEnabled,
      if (totals.length > 1)
        'meanPriorFocusMinutesBySameLocalTime':
            previousFocusByThisTime / (totals.length - 1),
      'priorWorkForActiveTags': [
        for (final tag in (activeTags.toList()..sort()).take(6))
          {
            'tag': _excerpt(tag, 36),
            'lastWorkDayInWindow': lastWorkByTag[tag],
            'completed': previousWorkByTag[tag]?.completed ?? 0,
            'focusMinutes': previousWorkByTag[tag]?.focus ?? 0,
            'manualMinutes': previousWorkByTag[tag]?.manual ?? 0,
          },
      ],
      'dailyColumns': [
        'created',
        'completed',
        'focus sessions',
        'focus minutes',
        'manual minutes',
        'new notes',
      ],
      'dailyTotals': {
        for (final entry in totals.entries) entry.key: entry.value.values,
      },
      'openNow': pendingByBucket,
      'topFocusMinutesTodayByTask': [
        for (final task in focused.take(5)) [task.title, task.minutes],
      ],
      'topFocusMinutesTodayByTag': [
        for (final tag in tags.take(6)) [_excerpt(tag.key, 36), tag.value],
      ],
      'todayExamples': today.take(10).toList(),
      'pendingExamples': pending.take(5).toList(),
      'historicalExamples': history.take(6).toList(),
    };
    return ReviewSnapshot._(
      day,
      now,
      payload,
      sha256.convert(utf8.encode(jsonEncode(material))).toString(),
      activeIds.isNotEmpty,
    );
  }

  // Retain exact totals even when the native model needs a smaller prompt.
  String prompt({required bool compact}) {
    final data = Map.of(payload);
    for (final key in [
      'todayExamples',
      'pendingExamples',
      'historicalExamples',
    ]) {
      final rows = payload[key] as List;
      final limit = switch (key) {
        'todayExamples' => compact ? 420 : 1700,
        'pendingExamples' => compact ? 180 : 650,
        _ => compact ? 240 : 850,
      };
      final samples = <Object?>[];
      var size = 0;
      for (final row in rows) {
        size += jsonEncode(row).length;
        if (samples.isNotEmpty && size > limit) break;
        samples.add(row);
      }
      data[key] = samples;
    }
    return jsonEncode(data);
  }
}
