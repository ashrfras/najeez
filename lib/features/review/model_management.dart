import 'package:flutter/material.dart';

import '../../core/design.dart';
import 'qwen_review_model.dart';

class ModelManagement extends StatelessWidget {
  const ModelManagement({
    super.key,
    required this.state,
    required this.busy,
    required this.download,
    required this.cancel,
    required this.remove,
  });
  final ModelInstallation state;
  final bool busy;
  final VoidCallback download, cancel, remove;

  @override
  Widget build(BuildContext context) {
    final fraction = state.total == 0
        ? 0.0
        : (state.received / state.total).clamp(0.0, 1.0);
    final content = switch (state.phase) {
      ModelPhase.unsupported =>
        'يتطلب النموذج iPhone متوافقًا بذاكرة كافية ومعالج رسومي مدعوم، ونظام iOS 16.4 أو أحدث.',
      ModelPhase.missing =>
        'حجم التنزيل نحو ${state.sizeLabel}. بعد التنزيل يعمل النموذج على جهازك دون اتصال.',
      ModelPhase.ready => 'مثبّت وجاهز للاستخدام',
      ModelPhase.downloading => 'جارٍ التنزيل · ${(fraction * 100).floor()}٪',
      ModelPhase.verifying => 'جارٍ التحقق من سلامة الملف قبل التثبيت…',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('النموذج المحلي · Qwen3 1.7B', style: AppType.section),
          const SizedBox(height: 6),
          Text(content, style: AppType.body),
          if (state.error.isNotEmpty)
            Text(QwenReviewModel.message(state.error), style: AppType.caption),
          if (state.transferring) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.phase == ModelPhase.verifying ? null : fraction,
            ),
            TextButton(onPressed: cancel, child: const Text('إلغاء التنزيل')),
          ],
          if (state.phase == ModelPhase.missing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton(
                onPressed: busy ? null : download,
                child: Text(
                  state.error.isEmpty ? 'تنزيل النموذج' : 'إعادة تنزيل النموذج',
                ),
              ),
            ),
          if (state.installed > 0 && !state.transferring)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: busy ? null : remove,
                child: const Text('حذف النموذج'),
              ),
            ),
        ],
      ),
    );
  }
}
