import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/theme/app_theme.dart';

/// Global search screen — searches medicines, companies & pharmacies
/// with a Glassmorphism design using the Deep Navy Blue palette.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;
  Timer? _debounce;

  // ── Results ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _medicines   = [];
  List<Map<String, dynamic>> _companies   = [];
  List<Map<String, dynamic>> _pharmacies  = [];

  bool _isSearching = false;
  String _lastQuery = '';

  // ── Recent searches (in-memory) ────────────────────────────────────
  final List<String> _recent = [];

  static const List<String> _tabs = ['الأدوية', 'الشركات', 'الصيدليات'];
  static const List<IconData> _tabIcons = [
    Icons.medication_rounded,
    Icons.business_rounded,
    Icons.local_pharmacy_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Debounced search ───────────────────────────────────────────────
  void _onQueryChanged() {
    final q = _searchCtrl.text.trim();
    if (q == _lastQuery) return;

    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _medicines = [];
        _companies = [];
        _pharmacies = [];
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    _lastQuery = q;
    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait<List<Map<String, dynamic>>>([
        db.searchMedicines(q),
        db.searchCompanies(q),
        db.searchPharmacies(q),
      ]);
      if (!mounted) return;
      setState(() {
        _medicines  = results[0];
        _companies  = results[1];
        _pharmacies = results[2];
        _isSearching = false;
      });
      // Save to recent
      if (!_recent.contains(q)) {
        setState(() {
          _recent.insert(0, q);
          if (_recent.length > 8) _recent.removeLast();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  int get _totalResults => _medicines.length + _companies.length + _pharmacies.length;

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            expandedHeight: 160,
            backgroundColor: isDark ? const Color(0xFF0F2040) : Colors.white,
            elevation: 0,
            foregroundColor: isDark ? Colors.white : AppTheme.primaryColor,
            // ── Hero gradient header ───────────────────────────────
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A4275), Color(0xFF0D2A50)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'البحث الشامل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ابحث في الأدوية والشركات والصيدليات',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ── Sticky search bar ──────────────────────────────────
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                color: isDark ? const Color(0xFF0F2040) : Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: _buildSearchBar(isDark),
              ),
            ),
          ),
          // ── Tab bar ───────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabCtrl,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: isDark ? const Color(0xFF8096AA) : const Color(0xFF8096AA),
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                tabs: List.generate(3, (i) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tabIcons[i], size: 16),
                      const SizedBox(width: 5),
                      Text(_tabs[i]),
                    ],
                  ),
                )),
              ),
              isDark: isDark,
            ),
          ),
        ],
        body: _lastQuery.isEmpty
            ? _buildEmptyState(isDark)
            : _isSearching
                ? _buildLoading()
                : _totalResults == 0
                    ? _buildNoResults(isDark)
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildMedicinesList(isDark),
                          _buildCompaniesList(isDark),
                          _buildPharmaciesList(isDark),
                        ],
                      ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF0D1F35),
        ),
        decoration: InputDecoration(
          hintText: 'ابحث عن دواء، شركة أو صيدلية...',
          hintStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: isDark ? const Color(0xFF8096AA) : const Color(0xFF8096AA),
          ),
          hintTextDirection: TextDirection.rtl,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          prefixIcon: _isSearching
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF8096AA),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _medicines = [];
                      _companies = [];
                      _pharmacies = [];
                      _lastQuery = '';
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ── Empty / initial state ─────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // Search hint
        _glassCard(
          isDark: isDark,
          accentColor: AppTheme.primaryColor,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.primaryColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'ابدأ البحث',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اكتب اسم دواء أو شركة أو صيدلية\nللبحث الفوري في قاعدة البيانات',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF8096AA) : const Color(0xFF8096AA),
                  fontFamily: 'Cairo',
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        if (_recent.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'عمليات البحث الأخيرة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _recent.clear()),
                child: Text(
                  'مسح الكل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.withValues(alpha: 0.8),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent.map((q) => GestureDetector(
              onTap: () {
                _searchCtrl.text = q;
                _searchCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: q.length),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppTheme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 13, color: const Color(0xFF8096AA)),
                    const SizedBox(width: 5),
                    Text(q,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],

        const SizedBox(height: 28),
        // Search tips
        _buildSearchTip(Icons.medication_rounded, const Color(0xFFE53935),
            'أدوية', 'ابحث بالاسم التجاري أو الفعال'),
        const SizedBox(height: 10),
        _buildSearchTip(Icons.business_rounded, const Color(0xFF2563A8),
            'شركات', 'ابحث باسم الشركة أو رمزها'),
        const SizedBox(height: 10),
        _buildSearchTip(Icons.local_pharmacy_rounded, const Color(0xFFFF8F00),
            'صيدليات', 'ابحث باسم الصيدلية أو المنطقة'),
      ],
    );
  }

  Widget _buildSearchTip(IconData icon, Color color, String label, String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
              Text(hint,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Color(0xFF8096AA),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'جاري البحث...',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: const Color(0xFF8096AA),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  color: AppTheme.primaryColor.withValues(alpha: 0.5), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: isDark ? Colors.white : const Color(0xFF0D1F35),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم نجد نتائج مطابقة لـ "$_lastQuery"',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8096AA),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Results lists ─────────────────────────────────────────────────

  Widget _buildMedicinesList(bool isDark) {
    if (_medicines.isEmpty) {
      return _emptyTab('لا توجد أدوية', Icons.medication_rounded, const Color(0xFFE53935));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _medicines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _medicineCard(_medicines[i], isDark),
    );
  }

  Widget _buildCompaniesList(bool isDark) {
    if (_companies.isEmpty) {
      return _emptyTab('لا توجد شركات', Icons.business_rounded, const Color(0xFF2563A8));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _companies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _companyCard(_companies[i], isDark),
    );
  }

  Widget _buildPharmaciesList(bool isDark) {
    if (_pharmacies.isEmpty) {
      return _emptyTab('لا توجد صيدليات', Icons.local_pharmacy_rounded, const Color(0xFFFF8F00));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _pharmacies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _pharmacyCard(_pharmacies[i], isDark),
    );
  }

  Widget _emptyTab(String msg, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color.withValues(alpha: 0.5), size: 36),
          ),
          const SizedBox(height: 14),
          Text(msg,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF8096AA),
                fontSize: 14,
              )),
        ],
      ),
    );
  }

  // ── Individual result cards ────────────────────────────────────────

  Widget _medicineCard(Map<String, dynamic> m, bool isDark) {
    final form    = m['form'] as String? ?? '';
    final source  = m['source'] as String? ?? '';
    final company = m['company_name'] as String? ?? '';
    final subtitle = [if (company.isNotEmpty) company, if (form.isNotEmpty) form]
        .join(' · ');
    return _glassCard(
      isDark: isDark,
      accentColor: const Color(0xFFE53935),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.medication_rounded,
                color: Color(0xFFE53935), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['name'] as String? ?? '',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0D1F35),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Color(0xFF8096AA),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (source.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A4275).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF1A4275).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                source,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4275),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _companyCard(Map<String, dynamic> c, bool isDark) {
    final name = c['name'] as String? ?? '';
    final code = c['code'] as String? ?? '';
    return _glassCard(
      isDark: isDark,
      accentColor: const Color(0xFF2563A8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A4275), Color(0xFF2563A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0D1F35),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'رمز: $code',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Color(0xFF8096AA),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded,
              color: const Color(0xFF8096AA), size: 20),
        ],
      ),
    );
  }

  Widget _pharmacyCard(Map<String, dynamic> p, bool isDark) {
    final name    = p['name'] as String? ?? '';
    final address = p['address'] as String? ?? '';
    final phone   = p['phone'] as String? ?? '';
    final meta = [if (address.isNotEmpty) address, if (phone.isNotEmpty) phone].join(' • ');
    return _glassCard(
      isDark: isDark,
      accentColor: const Color(0xFFFF8F00),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_pharmacy_rounded,
                color: Color(0xFFFF8F00), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0D1F35),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Color(0xFF8096AA),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded,
              color: const Color(0xFF8096AA), size: 20),
        ],
      ),
    );
  }

  // ── Glassmorphism card helper ──────────────────────────────────────
  Widget _glassCard({
    required bool isDark,
    required Widget child,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : accentColor.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}

// ── SliverPersistentHeaderDelegate for TabBar ─────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  _TabBarDelegate(this.tabBar, {required this.isDark});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF0A1628) : const Color(0xFFEEF2F8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F2040) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: tabBar,
      ),
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

