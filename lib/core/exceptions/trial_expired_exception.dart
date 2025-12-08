/// Exception thrown when trial mode has expired
/// (e.g., user exceeded pharmacy/company/medicine limit)
class TrialExpiredException implements Exception {
  final String limitType; // 'pharmacies', 'companies', 'medicines'
  final String message;

  TrialExpiredException(this.limitType,
      [this.message = 'انتهت النسخة التجريبية']);

  String getLimitTypeName() {
    switch (limitType) {
      case 'pharmacies':
        return 'الصيدليات';
      case 'companies':
        return 'الشركات';
      case 'medicines':
        return 'الأدوية';
      default:
        return '';
    }
  }

  @override
  String toString() => message;
}
