import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CloudCopy {
  const CloudCopy(this.date, this.data);
  final DateTime date;
  final Uint8List data;
}

class CloudBackup {
  static const _channel = MethodChannel('ma.raqmain.najeez/icloud');

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> checkAvailable() =>
      _channel.invokeMethod<void>('checkAvailable');

  Future<DateTime?> latestDate() async {
    final value = await _channel.invokeMethod<int>('latestDate');
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<DateTime> save(Uint8List data) async {
    final value = await _channel.invokeMethod<int>('save', data);
    if (value == null) throw const FormatException('Missing backup date');
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<CloudCopy?> read() async {
    final value = await _channel.invokeMapMethod<String, dynamic>('read');
    if (value == null) return null;
    return CloudCopy(
      DateTime.fromMillisecondsSinceEpoch(value['date'] as int),
      value['data'] as Uint8List,
    );
  }
}
