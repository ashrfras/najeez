import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'daily_review.dart';

class ReviewModel {
  static const _channel = MethodChannel('ma.raqmain.najeez/daily_review');

  Future<String> availability(String language) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return 'unsupported';
    }
    try {
      return await _channel.invokeMethod<String>('availability', {
            'language': language,
          }) ??
          'unavailable';
    } on MissingPluginException {
      return 'unsupported';
    } on PlatformException {
      return 'unavailable';
    }
  }

  Future<String> generate(ReviewSnapshot snapshot, String language) async =>
      await _channel.invokeMethod<String>('generate', {
        'language': language,
        'prompt': snapshot.prompt(compact: false),
        'compact': snapshot.prompt(compact: true),
      }) ??
      '';

  static String message(String code) => switch (code) {
    'unsupported' =>
      'يتطلب المراجع الذكي جهازًا يدعم Apple Intelligence ويعمل بنظام iOS 26 أو أحدث.',
    'disabled' =>
      'فعّل Apple Intelligence من إعدادات الجهاز لاستخدام المراجع الذكي.',
    'not_ready' =>
      'يُجهّز الجهاز نموذج Apple Intelligence. يمكنك المحاولة بعد اكتمال التنزيل.',
    'language' =>
      'نموذج Apple Intelligence على هذا الجهاز لا يدعم لغة واجهة نجيز حاليًا.',
    'interrupted' => 'توقف التحليل عند مغادرة التطبيق. يمكنك المحاولة مجددًا.',
    'context' => 'تعذّرت معالجة هذا الحجم من السجلات على الجهاز.',
    'unavailable' => 'نموذج Apple Intelligence غير متاح حاليًا على هذا الجهاز.',
    _ => 'تعذّر إكمال المراجعة وحفظها. حاول مرة أخرى.',
  };
}
