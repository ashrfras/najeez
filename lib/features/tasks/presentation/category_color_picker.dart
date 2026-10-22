import 'package:flutter/material.dart';

import '../../../core/design.dart';
import '../domain/task_controller.dart';

const _colorNames = [
  'أزرق',
  'بنفسجي',
  'أخضر',
  'برتقالي',
  'أحمر',
  'سماوي',
  'رمادي مزرق',
  'ليموني',
  'أصفر',
  'وردي',
  'نيلي',
  'رملي',
];

class CategoryColorPalette extends StatelessWidget {
  const CategoryColorPalette({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < AppColors.categoryPalette.length; i++)
        Semantics(
          selected: selected == AppColors.categoryPalette[i],
          child: IconButton(
            tooltip: _colorNames[i],
            onPressed: () => onSelected(AppColors.categoryPalette[i]),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.categoryPalette[i],
              foregroundColor: AppColors.background,
              side: BorderSide(
                color: selected == AppColors.categoryPalette[i]
                    ? AppColors.text
                    : Colors.transparent,
                width: 2,
              ),
            ),
            icon: Icon(
              selected == AppColors.categoryPalette[i] ? Icons.check : null,
            ),
          ),
        ),
    ],
  );
}

Future<Color?> editCategoryColor(
  BuildContext context,
  TaskController controller,
  String tag, {
  Color? initialColor,
}) async {
  final color = await showModalBottomSheet<Color>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('لون التصنيف: $tag', style: AppType.section),
            const SizedBox(height: 18),
            CategoryColorPalette(
              selected: initialColor ?? controller.categoryColor(tag),
              onSelected: (color) => Navigator.pop(context, color),
            ),
          ],
        ),
      ),
    ),
  );
  if (color == null) return null;
  try {
    await controller.setCategoryColor(tag, color);
    return color;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ لون التصنيف. حاول مرة أخرى.')),
      );
    }
    return null;
  }
}
