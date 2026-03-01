import 'package:flutter/material.dart';
import '../../core/services/subscription_service.dart';
import '../../core/models/subscription_plan.dart';
import '../../core/widgets/custom_app_bar.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  String? _errorMessage;
  List<SubscriptionPlan> _plans = [];
  String? _selectedPlanId; // null by default — no plan pre-selected
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _subscriptionService.fetchPlans();

      setState(() {
        _plans = response.plans.where((plan) => plan.enabled).toList();
        _currencySymbol = response.currency.symbol;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onPlanSelected(String planId) {
    setState(() {
      _selectedPlanId = planId;
    });
  }

  void _onContinue() {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار باقة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      '/contact-method',
      arguments: {
        'planId': _selectedPlanId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'اختر باقة الاشتراك'),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView(theme)
                : _plans.isEmpty
                    ? _buildEmptyView(theme)
                    : _buildPlansList(theme),
      ),
      bottomNavigationBar: _errorMessage == null && _plans.isNotEmpty
          ? _buildBottomBar(theme)
          : null,
    );
  }

  // ───────────────────── Bottom Bar ─────────────────────

  Widget _buildBottomBar(ThemeData theme) {
    final bool hasSelection = _selectedPlanId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hint text when no plan selected
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: hasSelection
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('hint'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 18, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'يرجى اختيار باقة للمتابعة',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            FilledButton(
              onPressed: hasSelection ? _onContinue : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.white,
              ),
              child: const Text(
                'متابعة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Error View ─────────────────────

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'تعذر تحميل الباقات، يرجى الاتصال بالإنترنت',
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchPlans,
              icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
              label: Text(
                'إعادة المحاولة',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Empty View ─────────────────────

  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'لا توجد باقات متاحة حالياً',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchPlans,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Plans List ─────────────────────

  Widget _buildPlansList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        final isSelected = _selectedPlanId == plan.id;
        final isRecommended = plan.recommended;

        return _PlanCard(
          plan: plan,
          isSelected: isSelected,
          isRecommended: isRecommended,
          currencySymbol: _currencySymbol,
          onTap: () => _onPlanSelected(plan.id),
          selectedPlanId: _selectedPlanId,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  _PlanCard — Reusable plan card with 3 distinct visual states
// ═══════════════════════════════════════════════════════════

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final bool isRecommended;
  final String currencySymbol;
  final VoidCallback onTap;
  final String? selectedPlanId;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isRecommended,
    required this.currencySymbol,
    required this.onTap,
    required this.selectedPlanId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── Determine visual style based on state ──
    final Color borderColor;
    final double borderWidth;
    final Color? cardColor;
    final double elevation;

    if (isSelected) {
      // ✅ SELECTED: Strong primary accent
      borderColor = theme.colorScheme.primary;
      borderWidth = 2.5;
      cardColor = theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08);
      elevation = 6;
    } else if (isRecommended) {
      // ⭐ RECOMMENDED (not selected): Subtle warm highlight, NO border change
      borderColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;
      borderWidth = 1;
      cardColor = Colors.amber.withValues(alpha: isDark ? 0.08 : 0.04);
      elevation = 2;
    } else {
      // 🔲 DEFAULT: Neutral
      borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
      borderWidth = 1;
      cardColor = theme.cardColor;
      elevation = 1;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: elevation,
        borderRadius: BorderRadius.circular(16),
        color: cardColor,
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // ⭐ Recommended badge — top-left (RTL = top-right visually)
                if (isRecommended)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade600,
                            Colors.orange.shade400,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '⭐',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'موصى بها',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ✅ Selection checkmark — top-right (RTL = top-left visually)
                if (isSelected)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: AnimatedScale(
                      scale: isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                // Card content
                Padding(
                  padding: EdgeInsets.only(
                    top: isRecommended ? 36 : 20,
                    bottom: 20,
                    left: 20,
                    right: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with radio
                      Row(
                        children: [
                          Radio<String>(
                            value: plan.id,
                            groupValue: selectedPlanId,
                            onChanged: (_) => onTap(),
                            activeColor: theme.colorScheme.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.textTheme.titleLarge?.color,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Duration
                      Padding(
                        padding: const EdgeInsets.only(right: 48),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                size: 16,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              '${plan.durationMonths} ${plan.durationMonths == 1 ? 'شهر' : 'أشهر'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),

                      // Description
                      if (plan.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(right: 48),
                          child: Text(
                            plan.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Divider
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                      ),

                      const SizedBox(height: 14),

                      // Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$currencySymbol${plan.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : isDark
                                      ? Colors.white
                                      : Colors.grey.shade800,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
