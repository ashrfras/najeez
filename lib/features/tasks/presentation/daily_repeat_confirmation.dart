import 'package:flutter/material.dart';

Future<bool> confirmDailyRepeat(
  BuildContext context, {
  required bool enabled,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          enabled ? 'تفعيل التكرار اليومي؟' : 'إيقاف التكرار اليومي؟',
        ),
        content: Text(
          enabled
              ? 'ستُضاف هذه المهمة تلقائيًا إلى قائمة «اليوم» مع بداية كل يوم جديد، حتى تقوم بإيقاف التكرار.'
              : 'لن تُضاف هذه المهمة تلقائيًا إلى قائمة «اليوم» بعد الآن، وستبقى المهام السابقة وسجلات إنجازها محفوظة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(enabled ? 'تفعيل التكرار' : 'إيقاف التكرار'),
          ),
        ],
      ),
    ) ??
    false;
