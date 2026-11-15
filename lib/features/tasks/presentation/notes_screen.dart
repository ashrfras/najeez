import 'package:flutter/material.dart';

import '../../../core/arabic_dates.dart';
import '../../../core/design.dart';
import '../domain/task.dart';
import '../domain/task_controller.dart';
import 'task_widgets.dart';

class NoteComposerScreen extends StatefulWidget {
  const NoteComposerScreen({
    super.key,
    required this.controller,
    required this.task,
    this.note,
  });
  final TaskController controller;
  final Task task;
  final TaskNote? note;

  @override
  State<NoteComposerScreen> createState() => _NoteComposerScreenState();
}

class _NoteComposerScreenState extends State<NoteComposerScreen> {
  final _text = TextEditingController();
  bool _saving = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _text.text = widget.note?.text ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!mounted || _canPop) return;
    setState(() {
      _saving = true;
      _canPop = true;
    });
    // Rebuild PopScope before requesting the intentional navigation.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_text.text.trim().isEmpty) {
      if (widget.note == null) {
        await _finish();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حفظ ملاحظة فارغة.')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.note == null) {
        await widget.controller.addNote(widget.task, _text.text);
      } else {
        await widget.controller.updateNote(
          widget.task,
          widget.note!,
          _text.text,
        );
      }
      if (mounted) await _finish();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ الملاحظة. حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    setState(() => _saving = true);
    final deleted = await _confirmDeleteNote(
      context,
      widget.controller,
      widget.task,
      widget.note,
    );
    if (!mounted) return;
    if (deleted) {
      await _finish();
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    if (_saving) return;
    setState(() => _saving = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق دون حفظ؟'),
        content: const Text('سيتم تجاهل التغييرات التي لم تُحفظ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إغلاق دون حفظ'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await _finish();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_saving) _save();
    },
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      autofocus: widget.note == null,
                      enabled: !_saving,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: AppType.body.copyWith(fontSize: 17, height: 1.6),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'اكتب ملاحظتك هنا...',
                        hintStyle: AppType.caption,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TaskLabel(task: widget.task),
                            if (widget.note != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                arabicDate(widget.note!.createdAt),
                                style: AppType.caption.copyWith(fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _saving ? null : _save,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          textStyle: AppType.caption,
                        ),
                        child: const Text('إغلاق'),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'خيارات الملاحظة',
                        enabled: !_saving,
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: AppColors.muted,
                        ),
                        onSelected: (value) {
                          if (value == 'discard') {
                            _discard();
                          } else {
                            _delete();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'discard',
                            child: Text('إغلاق دون حفظ'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TaskLabel extends StatelessWidget {
  const _TaskLabel({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.task_alt, size: 14, color: AppColors.muted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption,
        ),
      ),
    ],
  );
}

Future<bool> _confirmDeleteNote(
  BuildContext context,
  TaskController controller,
  Task task,
  TaskNote? note,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('حذف الملاحظة؟'),
      content: const Text('سيتم حذف هذه الملاحظة نهائيًا.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  if (note == null) return true;
  try {
    await controller.deleteNote(task, note);
    return true;
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذّر حذف الملاحظة. حاول مرة أخرى.')),
      );
    }
    return false;
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.controller,
    required this.task,
    required this.note,
  });
  final TaskController controller;
  final Task task;
  final TaskNote note;

  void _edit(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          NoteComposerScreen(controller: controller, task: task, note: note),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: panel(),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _edit(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.text,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(height: 1.6),
              ),
              const SizedBox(height: 14),
              _TaskLabel(task: task),
            ],
          ),
        ),
      ),
    ),
  );
}

// Independent columns let short notes sit directly beneath one another.
class _NotesGrid extends StatelessWidget {
  const _NotesGrid({required this.controller, required this.notes});
  final TaskController controller;
  final List<({Task task, TaskNote note})> notes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count =
          constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21
          ? 1
          : 2;
      final columns = List.generate(count, (_) => <Widget>[]);
      final heights = List.filled(count, 0.0);
      final width = (constraints.maxWidth - (count - 1) * 10) / count;
      for (final item in notes) {
        var column = 0;
        for (var i = 1; i < count; i++) {
          if (heights[i] < heights[column]) column = i;
        }
        final text = TextPainter(
          text: TextSpan(
            text: item.note.text,
            style: DefaultTextStyle.of(
              context,
            ).style.merge(AppType.body.copyWith(height: 1.6)),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 10,
        )..layout(maxWidth: width - 26);
        heights[column] += text.height + 65;
        text.dispose();
        columns[column].add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NoteCard(
              key: ValueKey(item.note.id),
              controller: controller,
              task: item.task,
              note: item.note,
            ),
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: columns[i],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class NotePreviewRow extends StatelessWidget {
  const NotePreviewRow({
    super.key,
    required this.controller,
    required this.task,
    required this.note,
  });
  final TaskController controller;
  final Task task;
  final TaskNote note;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            NoteComposerScreen(controller: controller, task: task, note: note),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.notes_outlined, size: 20, color: AppColors.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.text.replaceAll(RegExp(r'[\r\n]+'), ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body,
                ),
                const SizedBox(height: 6),
                _TaskLabel(task: task),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class RecentNotesSection extends StatelessWidget {
  const RecentNotesSection({super.key, required this.controller});
  final TaskController controller;

  void _openAll(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NotesScreen(controller: controller),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final notes = controller.searchNotes();
    return Container(
      decoration: panel(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _openAll(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.notes_outlined,
                      size: 18,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'آخر الملاحظات',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.section,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CountBadge(count: notes.length, color: AppColors.blue),
                ],
              ),
            ),
          ),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(13, 2, 13, 17),
              child: Text('لا توجد ملاحظات بعد', style: AppType.caption),
            ),
          for (final item in notes.take(3)) ...[
            NotePreviewRow(
              controller: controller,
              task: item.task,
              note: item.note,
            ),
            const Divider(
              height: 1,
              indent: 13,
              endIndent: 13,
              color: AppColors.border,
            ),
          ],
          TextButton(
            onPressed: () => _openAll(context),
            child: const Text('عرض الكل'),
          ),
        ],
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.controller});
  final TaskController controller;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 5),
                    const Text('جميع الملاحظات', style: AppType.section),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: panel(color: AppColors.surfaceRaised),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: AppType.body,
                    decoration: InputDecoration(
                      hintText: 'بحث في الملاحظات',
                      hintStyle: AppType.caption,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.muted,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_search.clear),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: widget.controller,
                    builder: (context, _) {
                      final notes = widget.controller.searchNotes(_search.text);
                      if (notes.isEmpty) {
                        return Center(
                          child: Text(
                            _search.text.trim().isEmpty
                                ? 'لا توجد ملاحظات بعد'
                                : 'لا توجد ملاحظات مطابقة',
                            style: AppType.caption,
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        child: _NotesGrid(
                          controller: widget.controller,
                          notes: notes,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
