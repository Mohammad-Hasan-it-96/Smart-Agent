import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/company.dart';
import 'company_form.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Company> _companies = [];
  List<Company> _filteredCompanies = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _searchController.addListener(_filterCompanies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final maps = await _dbHelper.query('companies', orderBy: 'name');
      setState(() {
        _companies = maps.map((map) => Company.fromMap(map)).toList();
        _filteredCompanies = _companies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterCompanies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCompanies = _companies;
      } else {
        _filteredCompanies = _companies
            .where((company) => company.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _deleteCompany(Company company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${company.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.delete(
          'companies',
          where: 'id = ?',
          whereArgs: [company.id],
        );
        _loadCompanies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الحذف بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدث خطأ أثناء الحذف')),
          );
        }
      }
    }
  }

  Future<void> _navigateToForm(Company? company) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyForm(company: company),
      ),
    );

    if (result == true) {
      _loadCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشركات'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCompanies.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'لا توجد شركات'
                              : 'لا توجد نتائج',
                          style: const TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredCompanies.length,
                        itemBuilder: (context, index) {
                          final company = _filteredCompanies[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                company.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _navigateToForm(company),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteCompany(company),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
