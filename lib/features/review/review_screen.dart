import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/activity_page.dart';
import '../../core/arabic_dates.dart';
import '../../core/design.dart';
import '../tasks/domain/task_controller.dart';
import 'daily_review.dart';
import 'review_model.dart';
import 'review_identity.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.controller, this.model});
  final TaskController controller;
  final ReviewModel? model;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with WidgetsBindingObserver {
  late String language;
  bool? available;
  String? error;
  Future<ReviewSnapshot>? snapshot;
  Timer? unlockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    language = Localizations.localeOf(context).toLanguageTag();
    _checkModel();
    _refresh();
  }

  Future<void> _checkModel() async {
    final model = widget.model;
    if (model == null) return;
    final locale = language;
    bool ready;
    try {
      ready = await model.isAvailable(locale);
    } catch (_) {
      ready = false;
    }
    if (mounted && model == widget.model && locale == language) {
      setState(() => available = ready);
    }
  }

  void _refresh() {
    final controller = widget.controller;
    unlockTimer?.cancel();
    final unlock = controller.reviewUnlockAt;
    if (widget.model != null &&
        unlock != null &&
        controller.now.isBefore(unlock)) {
      unlockTimer = Timer(unlock.difference(controller.now), _refresh);
    }
    setState(() {
      snapshot =
          widget.model != null &&
              controller.reviewAgeEligible &&
              !controller.reviewBusy
          ? controller.captureReview()
          : null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkModel();
      _refresh();
    }
  }

  @override
  void dispose() {
    unlockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _generate() async {
    final model = widget.model;
    if (model == null || available != true) return;
    setState(() => error = null);
    try {
      await widget.controller.generateReview(
        (data) => model.generate(data, language),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'تعذّر إكمال المراجعة وحفظها. حاول مرة أخرى.');
      await _checkModel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final saved = controller.dailyReview;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ActivityPage(
        content: (padding) => LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - padding.vertical).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ActivityPageHeader('المراجع الذكي'),
                        const SizedBox(height: 24),
                        if (saved != null)
                          _ReviewArticle(review: saved)
                        else
                          _ReviewIntro(busy: controller.reviewBusy),
                        if (controller.reviewBusy)
                          _GenerationStatus(showTitle: saved != null)
                        else
                          FutureBuilder<ReviewSnapshot>(
                            future: snapshot,
                            builder: _actions,
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: _PrivacyNote(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, AsyncSnapshot<ReviewSnapshot> result) {
    final controller = widget.controller;
    final saved = controller.dailyReview;
    if (widget.model == null) {
      return const _Notice(
        icon: Icons.info_outline_rounded,
        text: 'توليد مراجعات جديدة غير متاح حاليًا.',
      );
    }
    final ready = result.connectionState == ConnectionState.done;
    final data = result.data;
    final eligible = ready && data != null && data.changedSince(saved);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!controller.reviewAgeEligible)
          const _Notice(
            icon: Icons.calendar_today_outlined,
            text:
                'تتاح أول مراجعة بعد مرور سبعة أيام كاملة على بدء استخدام نجيز.',
          ),
        if (available == false)
          const _Notice(
            icon: Icons.memory_rounded,
            text: 'النموذج المحلي غير متاح حاليًا.',
          ),
        if (ready && data != null && !data.hasActivity)
          const _Notice(
            icon: Icons.edit_note_rounded,
            text:
                'تحتاج مراجعة اليوم إلى نشاط مسجّل، مثل إضافة مهمة أو إنجازها أو تسجيل وقت عمل.',
          ),
        if (error != null)
          _Notice(icon: Icons.info_outline_rounded, text: error!),
        if (result.hasError)
          TextButton(
            onPressed: _refresh,
            child: const Text('إعادة قراءة بيانات النشاط'),
          )
        else if (saved == null || eligible) ...[
          if (saved != null)
            const _Notice(
              icon: Icons.update_rounded,
              text:
                  'تغيّر سجل النشاط منذ المراجعة المعروضة. يمكنك الآن تحديث قراءتك لليوم.',
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.background,
                disabledBackgroundColor: AppColors.surfaceRaised,
                disabledForegroundColor: AppColors.muted,
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
              onPressed: eligible && available == true ? _generate : null,
              child: Text(
                saved == null ? 'تحليل إنتاجيتي' : 'تحديث المراجعة',
                style: AppType.body.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        if (available == false)
          TextButton(
            onPressed: _checkModel,
            child: const Text('التحقق من جاهزية النموذج'),
          ),
      ],
    );
  }
}

class _ReviewIntro extends StatelessWidget {
  const _ReviewIntro({required this.busy});
  final bool busy;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          height: 112,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: .52,
              colors: [AppColors.blueDim, AppColors.background],
            ),
          ),
          child: const ReviewMark(size: 56),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          liveRegion: busy,
          child: Text(
            busy ? 'قراءة نشاط اليوم' : 'مراجعة يومك',
            textAlign: TextAlign.center,
            style: AppType.title.copyWith(
              color: AppColors.text,
              fontSize: 28,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 370),
          child: Text(
            busy
                ? 'يحلّل المراجع ما سجّلته اليوم ويقارنه بسياق عملك السابق.'
                : 'اكتشف ما تقدّم اليوم، وأين توزّع تركيزك، وما يستحق انتباهك في العمل القادم.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.muted, height: 1.7),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ReviewArticle extends StatelessWidget {
  const _ReviewArticle({required this.review});
  final SavedDailyReview review;
  @override
  Widget build(BuildContext context) {
    final generated = review.generatedAt.toLocal(),
        asOf = review.asOf.toLocal();
    final paragraphs = review.text.trim().split(RegExp(r'\n\s*\n'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مراجعة ${arabicWeekday(review.day)}',
                      style: AppType.body.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${arabicDayMonth(review.day)} ${review.day.year}',
                      style: AppType.title.copyWith(
                        color: AppColors.text,
                        fontSize: 28,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const ReviewMark(size: 30),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                Icons.schedule_rounded,
                color: AppColors.muted,
                size: 16,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                DateUtils.isSameDay(review.day, generated)
                    ? 'وُلّدت الساعة ${timeLabel(generated)}'
                    : 'وُلّدت في ${arabicDate(generated)} ${generated.year}، الساعة ${timeLabel(generated)}',
                style: AppType.caption.copyWith(
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
        if (timeLabel(asOf) != timeLabel(generated))
          Text(
            'تشمل النشاط المسجل حتى ${timeLabel(asOf)}',
            style: AppType.caption.copyWith(color: AppColors.muted),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 44,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.blue, AppColors.blueDim],
                ),
              ),
            ),
            Expanded(child: Divider(height: 1, color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 22),
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < paragraphs.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == paragraphs.length - 1 ? 0 : 14,
                  ),
                  child: Text(
                    paragraphs[i],
                    style: AppType.body.copyWith(
                      color: AppColors.text,
                      fontSize: i == 0 ? 19 : 16,
                      fontWeight: i == 0 && paragraphs.length > 1
                          ? FontWeight.w700
                          : FontWeight.w400,
                      height: i == 0 ? 1.7 : 1.9,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 19, color: AppColors.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppType.body.copyWith(
                    color: AppColors.text,
                    height: 1.65,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerationStatus extends StatelessWidget {
  const _GenerationStatus({required this.showTitle});
  final bool showTitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          if (showTitle) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'جارٍ تحديث مراجعتك',
                style: AppType.section.copyWith(color: AppColors.text),
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: 160,
            child: TickerMode(
              enabled: !MediaQuery.disableAnimationsOf(context),
              child: LinearProgressIndicator(
                semanticsLabel: 'جارٍ تحليل نشاط اليوم',
                color: AppColors.blue,
                backgroundColor: AppColors.border,
                minHeight: 3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phonelink_lock_rounded,
                color: AppColors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خصوصية المراجعة',
                    style: AppType.body.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'تُحفظ المراجعة على جهازك. لا تُرسل بيانات نشاطك إلى خوادم لإجراء التحليل.',
                    style: AppType.caption.copyWith(
                      color: AppColors.muted,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
