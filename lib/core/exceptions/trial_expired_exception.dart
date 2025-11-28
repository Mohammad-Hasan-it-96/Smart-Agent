/// Exception thrown when trial mode has expired
/// (e.g., user exceeded pharmacy limit)
class TrialExpiredException implements Exception {
  final String message;

  TrialExpiredException([this.message = 'انتهت النسخة التجريبية']);

  @override
  String toString() => message;
}
