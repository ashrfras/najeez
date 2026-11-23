import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'daily_review.dart';
import 'review_model.dart';
import 'review_evidence.dart';

enum ModelPhase { unsupported, missing, downloading, verifying, ready }

class ModelInstallation {
  const ModelInstallation(
    this.phase, {
    this.total = 0,
    this.received = 0,
    this.installed = 0,
    this.error = '',
  });
  final ModelPhase phase;
  final int total, received, installed;
  final String error;
  bool get transferring =>
      phase == ModelPhase.downloading || phase == ModelPhase.verifying;
  String get sizeLabel =>
      '${((installed > 0 ? installed : total) / 1e9).toStringAsFixed(2)} غيغابايت';

  factory ModelInstallation.decode(Object? raw) {
    final map = raw as Map;
    return ModelInstallation(
      ModelPhase.values.byName(map['phase'] as String),
      total: map['total'] as int,
      received: map['received'] as int,
      installed: map['installed'] as int,
      error: map['error'] as String,
    );
  }
}

class QwenReviewModel implements ReviewModel {
  const QwenReviewModel();
  static const _channel = MethodChannel('ma.raqmain.najeez/qwen');
  static const _events = EventChannel('ma.raqmain.najeez/qwen/state');
  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Stream<ModelInstallation> get changes => _ios
      ? _events.receiveBroadcastStream().map(ModelInstallation.decode)
      : const Stream.empty();

  Future<ModelInstallation> status() async {
    if (!_ios) return const ModelInstallation(ModelPhase.unsupported);
    return ModelInstallation.decode(await _channel.invokeMethod('status'));
  }

  @override
  Future<bool> isAvailable(String language) async =>
      (await status()).phase == ModelPhase.ready;

  Future<void> download() => _channel.invokeMethod<void>('download');
  Future<void> cancelDownload() =>
      _channel.invokeMethod<void>('cancelDownload');
  Future<void> remove() => _channel.invokeMethod<void>('remove');
  Future<void> cancelGeneration() =>
      _channel.invokeMethod<void>('cancelGeneration');

  @override
  Future<String> generate(ReviewSnapshot snapshot, String language) async {
    final text = await _channel.invokeMethod<String>(
      'generate',
      qwenEvidence(snapshot),
    );
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Empty review');
    }
    return text;
  }

  static String message(String code) => switch (code) {
    'memory' =>
      'الذاكرة المتاحة غير كافية الآن. أغلق التطبيقات الثقيلة ثم حاول مجددًا.',
    'storage' => 'تعذّر حفظ النموذج. تحقق من المساحة المتاحة على الجهاز.',
    'integrity' => 'لم يجتز الملف فحص السلامة. أعد تنزيله.',
    'network' => 'لم يكتمل التنزيل. تحقق من الاتصال ثم أعد المحاولة.',
    'thermal' => 'حرارة الجهاز مرتفعة. حاول بعد أن يبرد.',
    'cancelled' => 'توقف توليد المراجعة.',
    'busy' => 'انتظر انتهاء العملية الحالية.',
    _ => 'تعذّر إكمال العملية. حاول مرة أخرى.',
  };
}
