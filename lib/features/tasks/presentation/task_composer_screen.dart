import 'package:flutter/material.dart';

import '../../../core/design.dart';
import '../domain/task.dart';
import '../domain/task_controller.dart';
import '../domain/task_dates.dart';
import 'category_color_picker.dart';

class TaskComposerScreen extends StatefulWidget {
  const TaskComposerScreen({
    super.key,
    required this.controller,
    this.initialBucket = TaskBucket.today,
    this.task,
  });

  final TaskController controller;
  final TaskBucket initialBucket;
  final Task? task;

  @override
  State<TaskComposerScreen> createState() => _TaskComposerScreenState();
}

class _TaskComposerScreenState extends State<TaskComposerScreen> {
  final _title = TextEditingController();
  final _newTag = TextEditingController();
  final _tagFocus = FocusNode();
  late TaskBucket _bucket;
  String? _selectedTag;
  bool _addingTag = false;
  bool _saving = false;
  final Map<String, Color> _pendingColors = {};

  Color _tagColor(String tag) =>
      _pendingColors[tag.trim()] ?? widget.controller.categoryColor(tag);

  @override
  void initState() {
    super.initState();
    _bucket = widget.task == null
        ? widget.initialBucket
        : visibleBucket(
            widget.task!,
            widget.controller.now,
            widget.controller.logicalDay,
          );
    _title.text = widget.task?.title ?? '';
    _selectedTag = widget.task?.tag;
  }

  @override
  void dispose() {
    _title.dispose();
    _newTag.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    final tag = _addingTag ? _newTag.text.trim() : _selectedTag;
    setState(() => _saving = true);
    try {
      final color = _pendingColors[tag];
      if (tag != null && color != null) {
        await widget.controller.setCategoryColor(tag, color);
      }
      if (widget.task == null) {
        await widget.controller.create(title, bucket: _bucket, tag: tag);
      } else {
        await widget.controller.update(
          widget.task!,
          title,
          bucket: _bucket,
          tag: tag,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ المهمة. حاول مرة أخرى.')),
        );
      }
    }
  }

  void _startNewTag() {
    setState(() {
      _addingTag = true;
      _selectedTag = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tagFocus.requestFocus();
    });
  }

  void _acceptNewTag() {
    final value = _newTag.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _selectedTag = value;
      _addingTag = false;
    });
    _tagFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tags = [...widget.controller.availableTags];
    if (_selectedTag != null && !tags.contains(_selectedTag)) {
      tags.insert(0, _selectedTag!);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 22),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.task == null ? 'إضافة مهمة' : 'تعديل المهمة',
                            style: AppType.section,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: panel(radius: 12),
                            child: const Icon(Icons.close, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: panel(color: AppColors.surfaceRaised),
                            child: TextField(
                              controller: _title,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              maxLines: 3,
                              minLines: 1,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _submit(),
                              style: AppType.body.copyWith(fontSize: 17),
                              decoration: const InputDecoration(
                                hintText: 'ما المهمة التي تريد إنجازها؟',
                                hintStyle: AppType.caption,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 17,
                                  vertical: 17,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _BucketOption(
                                  label: 'اليوم',
                                  icon: Icons.adjust,
                                  color: AppColors.blue,
                                  selected: _bucket == TaskBucket.today,
                                  onTap: () => setState(
                                    () => _bucket = TaskBucket.today,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: _BucketOption(
                                  label: 'غداً',
                                  icon: Icons.calendar_month_outlined,
                                  color: AppColors.blue,
                                  selected: _bucket == TaskBucket.tomorrow,
                                  onTap: () => setState(
                                    () => _bucket = TaskBucket.tomorrow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: _BucketOption(
                                  label: 'لاحقاً',
                                  icon: Icons.all_inclusive,
                                  color: AppColors.orange,
                                  selected: _bucket == TaskBucket.later,
                                  onTap: () => setState(
                                    () => _bucket = TaskBucket.later,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'وسم (اختياري)',
                            style: AppType.caption.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 11),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in tags)
                                _TagOption(
                                  label: tag,
                                  color: _tagColor(tag),
                                  onLongPress: () async {
                                    final color = await editCategoryColor(
                                      context,
                                      widget.controller,
                                      tag,
                                      initialColor: _tagColor(tag),
                                    );
                                    if (mounted && color != null) {
                                      setState(
                                        () => _pendingColors.remove(tag),
                                      );
                                    }
                                  },
                                  selected: _selectedTag == tag && !_addingTag,
                                  onTap: () => setState(() {
                                    _selectedTag = _selectedTag == tag
                                        ? null
                                        : tag;
                                    _addingTag = false;
                                    _newTag.clear();
                                  }),
                                ),
                              _TagOption(
                                label: 'وسم جديد +',
                                selected: _addingTag,
                                onTap: _startNewTag,
                              ),
                            ],
                          ),
                          if (_addingTag) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: panel(color: AppColors.surfaceRaised),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _newTag,
                                      focusNode: _tagFocus,
                                      maxLength: 30,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (_) => setState(() {}),
                                      onSubmitted: (_) => _acceptNewTag(),
                                      decoration: const InputDecoration(
                                        hintText: 'اسم الوسم الجديد',
                                        hintStyle: AppType.caption,
                                        border: InputBorder.none,
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _acceptNewTag,
                                    icon: const Icon(
                                      Icons.check,
                                      color: AppColors.blue,
                                    ),
                                    tooltip: 'اعتماد الوسم',
                                  ),
                                ],
                              ),
                            ),
                            if (_newTag.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text('لون التصنيف', style: AppType.caption),
                              const SizedBox(height: 8),
                              CategoryColorPalette(
                                selected: _tagColor(_newTag.text.trim()),
                                onSelected: (color) => setState(() {
                                  _pendingColors[_newTag.text.trim()] = color;
                                }),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _title.text.trim().isEmpty || _saving
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          disabledBackgroundColor: AppColors.blueDim,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                        ),
                        child: Text(
                          _saving
                              ? 'جارٍ الحفظ...'
                              : widget.task == null
                              ? 'إضافة'
                              : 'حفظ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
}

class _BucketOption extends StatelessWidget {
  const _BucketOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.control),
    child: Container(
      height: 80,
      decoration: panel(
        color: selected ? color.withValues(alpha: .12) : AppColors.surface,
        radius: AppRadius.control,
        border: selected ? color : AppColors.border,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 7),
          Text(
            label,
            style: AppType.body.copyWith(
              color: selected ? AppColors.text : AppColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TagOption extends StatelessWidget {
  const _TagOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.blue,
    this.onLongPress,
  });
  final String label;
  final VoidCallback? onLongPress;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: onLongPress,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: panel(
        color: color.withValues(alpha: selected ? .2 : .1),
        radius: 20,
        border: selected ? color : AppColors.border,
      ),
      child: Text(label, style: AppType.caption.copyWith(color: color)),
    ),
  );
}
