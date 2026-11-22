import 'daily_review.dart';

/// On-device generation is optional. Stored reviews can be read without a model.
abstract interface class ReviewModel {
  Future<bool> isAvailable(String language);
  Future<String> generate(ReviewSnapshot snapshot, String language);
}
