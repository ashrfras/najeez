import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/design.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _InfoPage(
    title: 'سياسة الخصوصية',
    children: [
      _InfoSection(
        title: 'خصوصيتك في نجيز',
        body:
            'نجيز تطبيق لتنظيم المهام وتسجيل وقت العمل، تنشره Raqmain. '
            'تصف هذه السياسة طريقة تعامل الإصدار الحالي مع بياناتك.',
      ),
      _InfoSection(
        title: 'البيانات التي يحفظها التطبيق',
        body:
            'يحفظ نجيز عناوين المهام ووسومها وتصنيفها ومواعيدها، '
            'وتواريخ إنشائها وتعديلها وإكمالها وحالة حذفها. '
            'ويحفظ مدد العمل التي تسجّلها وتواريخ إدخالها، '
            'وإعداد بداية اليوم المنطقي. تُستخدم هذه البيانات لعرض مهامك '
            'وسجل إنجازك وحساب إحصاءات العمل داخل التطبيق.',
      ),
      _InfoSection(
        title: 'التخزين على جهازك',
        body:
            'تُحفظ بياناتك في قاعدة بيانات محلية على جهازك، '
            'وفي تخزين المتصفح عند استخدام نسخة الويب. '
            'تعمل إدارة المهام والإحصاءات دون اتصال بالإنترنت، '
            'ولا يرسل التطبيق محتوى مهامك أو سجلات وقتك إلى خوادم Raqmain.',
      ),
      _InfoSection(
        title: 'الحسابات والمشاركة والتتبّع',
        body:
            'لا يتطلب نجيز إنشاء حساب أو إدخال اسم أو بريد إلكتروني. '
            'ولا يتضمن الإصدار الحالي إعلانات أو أدوات تحليلات أو تتبّع، '
            'ولا يبيع التطبيق بيانات مهامك؛ ويستخدم iCloud فقط عند اختيار الحفظ السحابي. '
            'ولا يطلب الوصول إلى موقعك أو جهات اتصالك أو الكاميرا أو الميكروفون.',
      ),
      _InfoSection(
        title: 'الاحتفاظ بالبيانات وحذفها',
        body:
            'تبقى البيانات في التخزين المحلي ما لم تُمسح بيانات التطبيق. '
            'عند حذف مهمة، تُخفى من القوائم والإحصاءات مع بقاء سجلها '
            'في قاعدة البيانات المحلية؛ ولا يُعد ذلك مسحاً نهائياً. '
            'لحذف بياناتك المحلية بالكامل، استخدم خيار «إعادة الضبط» '
            'من إعدادات التطبيق. يؤدي ذلك إلى مسح المهام وسجلات الوقت '
            'والإعدادات المحفوظة محلياً بشكل نهائي.',
      ),
      _InfoSection(
        title: 'النسخ الاحتياطي وحماية البيانات',
        body:
            'يمكنك تفعيل الحفظ السحابي على iOS لحفظ نسخة واحدة من جميع '
            'بياناتك وإعداداتك في قاعدة CloudKit الخاصة بحساب Apple لديك. '
            'تُستبدل النسخة بعد نجاح الحفظ الجديد، ويمكن استعادتها على جهاز آخر '
            'باستخدام الحساب نفسه. تعطيل الحفظ السحابي أو إعادة ضبط التطبيق '
            'لا يحذف النسخة الموجودة في iCloud. لا تملك Raqmain نسخة من بياناتك. '
            'تخضع خدمة iCloud لإعدادات حسابك وسياسات Apple. '
            'قاعدة البيانات المحلية ليست مشفّرة بواسطة التطبيق، وتعتمد حمايتها '
            'على وسائل حماية الجهاز أو المتصفح.',
      ),
      _InfoSection(
        title: 'تحديث هذه السياسة',
        body:
            'إذا تغيّرت طريقة تعامل نجيز مع البيانات، ستُحدّث هذه '
            'السياسة ضمن إصدار التطبيق الذي يتضمن التغيير.',
      ),
    ],
  );
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) => _InfoPage(
    title: 'عن التطبيق',
    children: [
      Container(
        decoration: panel(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const _DetailRow(label: 'الناشر', value: 'Raqmain®'),
            const Divider(height: 30, color: AppColors.border),
            const _DetailRow(
              label: 'الدعم والتواصل',
              value: 'support@raqmain.ma',
            ),
            const Divider(height: 30, color: AppColors.border),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text('تعذّر تحميل معلومات النسخة.'),
                      TextButton(
                        onPressed: () => setState(() {
                          _packageInfo = PackageInfo.fromPlatform();
                        }),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  );
                }
                final info = snapshot.data;
                return Column(
                  children: [
                    _DetailRow(label: 'النسخة', value: info?.version ?? '…'),
                    const Divider(height: 30, color: AppColors.border),
                    _DetailRow(
                      label: 'التصحيح (رقم البناء)',
                      value: info?.buildNumber ?? '…',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      Column(
        children: [
          Image.asset('assets/logo_mark.png', width: 88, height: 88),
          Transform.translate(
            offset: const Offset(0, -6),
            child: const Text(
              'سجّل مهامك بسرعة، وأنجزها ببساطة.',
              style: AppType.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ],
  );
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: false,
      title: Text(title, style: AppType.section),
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SelectionArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(height: 20),
              itemBuilder: (_, index) => children[index],
            ),
          ),
        ),
      ),
    ),
  );
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppType.section),
      const SizedBox(height: 10),
      Text(body, style: AppType.body.copyWith(height: 1.9)),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppType.body)),
      const SizedBox(width: 16),
      Flexible(
        child: Text(
          value,
          textDirection: TextDirection.ltr,
          style: AppType.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
