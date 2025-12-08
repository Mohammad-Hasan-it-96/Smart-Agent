import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/company.dart';
import '../../core/services/activation_service.dart';
import '../../core/exceptions/trial_expired_exception.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/empty_state.dart';
import 'company_form.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ActivationService _activationService = ActivationService();
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
    // If adding new company, check trial limit first
    if (company == null) {
      try {
        await _activationService.checkTrialLimitCompanies();
      } on TrialExpiredException {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('وصلت للحد المسموح'),
              content: const Text(
                  'وصلت للحد المسموح في النسخة التجريبية. يرجى التواصل مع المطور لتفعيل التطبيق.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/activation',
                      (route) => false,
                    );
                  },
                  child: const Text('تواصل مع المطور'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    final result = await Navigator.push(
      context,
      SlidePageRoute(
        page: CompanyForm(company: company),
        direction: SlideDirection.rightToLeft,
      ),
    );

    if (result == true) {
      _loadCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'الشركات'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث عن شركة...',
                  prefixIcon: const Icon(Icons.search),
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCompanies.isEmpty
                      ? EmptyState(
                          icon: _searchController.text.isEmpty
                              ? Icons.business
                              : Icons.search_off,
                          title: _searchController.text.isEmpty
                              ? 'لا توجد شركات'
                              : 'لا توجد نتائج',
                          message: _searchController.text.isEmpty
                              ? 'ابدأ بإضافة شركة جديدة'
                              : 'لم يتم العثور على شركات تطابق البحث',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredCompanies.length,
                          itemBuilder: (context, index) {
                            final company = _filteredCompanies[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.business,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                title: Text(
                                  company.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _navigateToForm(company),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.edit,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _deleteCompany(company),
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة شركة'),
      ),
    );
  }
}
