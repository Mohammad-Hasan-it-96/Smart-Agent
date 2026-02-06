import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import '../models/company.dart';
import '../models/medicine.dart';
import 'activation_service.dart';

class DataExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ActivationService _activationService = ActivationService();

  /// Export companies and medicines to JSON file
  Future<File> exportData() async {
    // Check offline limit before exporting
    final offlineLimitExceeded = await _activationService.isOfflineLimitExceeded();
    if (offlineLimitExceeded) {
      throw Exception('OFFLINE_LIMIT_EXCEEDED');
    }
    // Fetch all companies
    final companyMaps = await _dbHelper.query('companies', orderBy: 'name');
    final companies = companyMaps.map((map) => Company.fromMap(map)).toList();

    // Fetch all medicines
    final medicineMaps = await _dbHelper.query('medicines', orderBy: 'name');
    final medicines = medicineMaps.map((map) => Medicine.fromMap(map)).toList();

    // Create export data structure with ALL fields
    final exportData = {
      'version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'companies': companies.map((c) => {
            'id': c.id,
            'name': c.name,
          }).toList(),
      'medicines': medicines.map((m) => {
            'id': m.id,
            'name': m.name,
            'company_id': m.companyId,
            'company_name': _getCompanyName(companies, m.companyId),
            'price_usd': m.priceUsd,
            'source': m.source,
            'form': m.form,
            'notes': m.notes,
          }).toList(),
    };

    // Convert to JSON string
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/smart_agent_data_$timestamp.json');

    // Write to file using UTF-8 encoding (write bytes, NOT plain String)
    final utf8Bytes = utf8.encode(jsonString);
    await file.writeAsBytes(utf8Bytes);

    return file;
  }

  /// Share the exported file
  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'بيانات الشركات والأدوية - المندوب الذكي',
      subject: 'Smart Agent Data Export',
    );
  }

  /// Get company name by ID
  String? _getCompanyName(List<Company> companies, int companyId) {
    try {
      return companies.firstWhere((c) => c.id == companyId).name;
    } catch (e) {
      return null;
    }
  }

  /// Import data from JSON file
  /// Accepts UTF-8 encoded bytes or string
  Future<ImportResult> importData(dynamic jsonInput) async {
    try {
      // Handle both String and List<int> (bytes)
      String jsonString;
      if (jsonInput is List<int>) {
        // Decode UTF-8 bytes to string
        jsonString = utf8.decode(jsonInput);
      } else if (jsonInput is String) {
        jsonString = jsonInput;
      } else {
        throw FormatException('Invalid input type for import');
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (data['companies'] == null || data['medicines'] == null) {
        throw FormatException('Invalid file format: missing companies or medicines');
      }

      final companiesData = data['companies'] as List<dynamic>;
      final medicinesData = data['medicines'] as List<dynamic>;

      int companiesAdded = 0;
      int companiesSkipped = 0;
      int medicinesAdded = 0;
      int medicinesSkipped = 0;

      // Get existing companies and medicines for duplicate checking
      final existingCompanyMaps = await _dbHelper.query('companies');
      final existingCompanies = existingCompanyMaps
          .map((map) => Company.fromMap(map))
          .toList();
      final existingCompanyNames =
          existingCompanies.map((c) => c.name.toLowerCase()).toSet();

      final existingMedicineMaps = await _dbHelper.query('medicines');
      final existingMedicines = existingMedicineMaps
          .map((map) => Medicine.fromMap(map))
          .toList();
      final existingMedicineKeys = existingMedicines
          .map((m) => '${m.name.toLowerCase()}_${m.companyId}')
          .toSet();

      // Create a map of company names to IDs for medicine import
      final companyNameToId = <String, int>{};
      for (final company in existingCompanies) {
        companyNameToId[company.name.toLowerCase()] = company.id!;
      }

      // Import companies
      for (final companyData in companiesData) {
        final companyMap = companyData as Map<String, dynamic>;
        final companyName = companyMap['name'] as String?;

        if (companyName == null || companyName.trim().isEmpty) {
          companiesSkipped++;
          continue;
        }

        // Check for duplicates (case-insensitive)
        if (existingCompanyNames.contains(companyName.toLowerCase())) {
          companiesSkipped++;
          continue;
        }

        // Insert new company
        final newCompanyId = await _dbHelper.insert('companies', {
          'name': companyName.trim(),
        });

        // Update mapping
        companyNameToId[companyName.toLowerCase()] = newCompanyId;
        existingCompanyNames.add(companyName.toLowerCase());
        companiesAdded++;
      }

      // Import medicines
      for (final medicineData in medicinesData) {
        final medicineMap = medicineData as Map<String, dynamic>;
        final medicineName = medicineMap['name'] as String?;
        
        if (medicineName == null || medicineName.trim().isEmpty) {
          medicinesSkipped++;
          continue;
        }

        // Get company ID using company_name (since IDs differ between databases)
        // company_id in export is kept for reference but we match by name
        int? companyId;
        final companyName = medicineMap['company_name'] as String?;
        if (companyName != null && companyName.trim().isNotEmpty) {
          companyId = companyNameToId[companyName.toLowerCase()];
        }

        if (companyId == null) {
          medicinesSkipped++;
          continue;
        }

        // Check for duplicates (same name + company)
        final medicineKey = '${medicineName.toLowerCase().trim()}_$companyId';
        if (existingMedicineKeys.contains(medicineKey)) {
          medicinesSkipped++;
          continue;
        }

        // Insert new medicine with ALL fields
        await _dbHelper.insert('medicines', {
          'name': medicineName.trim(),
          'company_id': companyId,
          'price_usd': (medicineMap['price_usd'] as num?)?.toDouble() ?? 0.0,
          'source': (medicineMap['source'] as String?)?.trim().isEmpty == true
              ? null
              : (medicineMap['source'] as String?)?.trim(),
          'form': (medicineMap['form'] as String?)?.trim().isEmpty == true
              ? null
              : (medicineMap['form'] as String?)?.trim(),
          'notes': (medicineMap['notes'] as String?)?.trim().isEmpty == true
              ? null
              : (medicineMap['notes'] as String?)?.trim(),
        });

        existingMedicineKeys.add(medicineKey);
        medicinesAdded++;
      }

      return ImportResult(
        companiesAdded: companiesAdded,
        companiesSkipped: companiesSkipped,
        medicinesAdded: medicinesAdded,
        medicinesSkipped: medicinesSkipped,
      );
    } catch (e) {
      throw Exception('Failed to import data: ${e.toString()}');
    }
  }
}

class ImportResult {
  final int companiesAdded;
  final int companiesSkipped;
  final int medicinesAdded;
  final int medicinesSkipped;

  ImportResult({
    required this.companiesAdded,
    required this.companiesSkipped,
    required this.medicinesAdded,
    required this.medicinesSkipped,
  });
}

