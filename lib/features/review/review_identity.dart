import 'package:flutter/material.dart';

import '../../core/design.dart';

class ReviewMark extends StatelessWidget {
  const ReviewMark({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(Icons.auto_awesome_rounded, color: AppColors.blue, size: size),
  );
}

class ReviewEntryCard extends StatelessWidget {
  const ReviewEntryCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.border),
    );
    return Semantics(
      button: true,
      child: Material(
        shape: shape,
        clipBehavior: Clip.antiAlias,
        color: AppColors.surface,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [AppColors.surface, AppColors.surfaceRaised],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المراجع الذكي',
                          style: AppType.section.copyWith(
                            fontSize: 19,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'قراءة في إنجاز اليوم وتركيزك',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ReviewMark(size: 32),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.muted,
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
