import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/gift.dart';
import '../../core/utils/slide_page_route.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/index/index_design_system.dart';
import 'gift_form.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  static const _pageSize = 30;

  List<Gift> _gifts = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadGifts(reset: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGifts({required bool reset}) async {
    if (reset) {
      setState(() {
        _isInitialLoading = true;
        _isLoadingMore = false;
        _currentPage = 0;
        _hasMoreData = true;
      });
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final db = await _dbHelper.database;
      final offset = reset ? 0 : _currentPage * _pageSize;
      final where = _searchQuery.isNotEmpty ? 'name LIKE ?' : null;
      final whereArgs = _searchQuery.isNotEmpty ? ['%$_searchQuery%'] : null;

      final rows = await db.query(
        'gifts',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
        limit: _pageSize,
        offset: offset,
      );

      final items = rows.map(Gift.fromMap).toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _gifts = items;
        } else {
          _gifts.addAll(items);
        }
        _currentPage = reset ? 1 : _currentPage + 1;
        _hasMoreData = items.length == _pageSize;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = _searchController.text.trim();
      if (q == _searchQuery) return;
      setState(() => _searchQuery = q);
      _loadGifts(reset: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMoreData) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.8) _loadGifts(reset: false);
  }

  Future<void> _deleteGift(Gift gift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: Text('هل تريد حذف "${gift.name}"؟', textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _dbHelper.delete('gifts', where: 'id = ?', whereArgs: [gift.id]);
    await _loadGifts(reset: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف ${gift.name}')),
      );
    }
  }

  Future<void> _navigateToForm(Gift? gift) async {
    final result = await Navigator.push(
      context,
      SlidePageRoute(
        page: GiftForm(gift: gift),
        direction: SlideDirection.rightToLeft,
      ),
    );
    if (result == true) await _loadGifts(reset: true);
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return ListView.builder(
        padding: IndexUiTokens.listBottomPadding,
        itemCount: 6,
        itemBuilder: (_, __) => const IndexSkeletonCard(),
      );
    }

    if (_gifts.isEmpty) {
      final hasFilter = _searchQuery.isNotEmpty;
      return IndexEmptySection(
        icon: hasFilter ? Icons.search_off_rounded : Icons.card_giftcard_rounded,
        title: hasFilter ? 'لا توجد نتائج' : 'لا توجد هدايا بعد',
        message: hasFilter
            ? 'جرّب تغيير البحث.'
            : 'ابدأ بإضافة هدايا (أجهزة، ستاندات...) لاستخدامها في الطلبيات.',
        onAdd: () => _navigateToForm(null),
        addLabel: 'إضافة هدية',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: IndexUiTokens.listBottomPadding,
      itemCount: _gifts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _gifts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildCard(_gifts[index]);
      },
    );
  }

  Widget _buildCard(Gift gift) {
    final theme = Theme.of(context);
    return Card(
      margin: IndexUiTokens.cardMargin,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IndexUiTokens.cardRadius)),
      elevation: 1.5,
      child: Padding(
        padding: IndexUiTokens.cardPadding,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.card_giftcard_rounded,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((gift.notes ?? '').isNotEmpty)
                      Text(
                        gift.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _navigateToForm(gift);
                  if (v == 'delete') _deleteGift(gift);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'الهدايا',
        showNotifications: true,
        showSettings: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            IndexHeaderSection(
              searchController: _searchController,
              searchQuery: _searchQuery,
              hintText: 'ابحث عن هدية...',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadGifts(reset: true),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة هدية'),
      ),
    );
  }
}

