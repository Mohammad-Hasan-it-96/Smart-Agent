import 'package:flutter/material.dart';
import '../../core/services/subscription_service.dart';
import '../../core/models/subscription_plan.dart';
import '../../core/widgets/custom_app_bar.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  String? _errorMessage;
  List<SubscriptionPlan> _plans = [];
  String? _selectedPlanId;
  String _currencySymbol = '\$';
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canContinue = false;
    });

    try {
      final response = await _subscriptionService.fetchPlans();
      
      setState(() {
        // Filter only enabled plans
        _plans = response.plans.where((plan) => plan.enabled).toList();
        _currencySymbol = response.currency.symbol;
        _isLoading = false;
        _canContinue = _plans.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _canContinue = false;
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

    // Navigate to contact method screen
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
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? _buildErrorView(theme)
                : _plans.isEmpty
                    ? _buildEmptyView(theme)
                    : _buildPlansList(theme),
      ),
      bottomNavigationBar: _errorMessage == null && _plans.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: FilledButton(
                  onPressed: _canContinue && _selectedPlanId != null
                      ? _onContinue
                      : null,
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
              ),
            )
          : null,
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'تعذر تحميل الباقات، يرجى الاتصال بالإنترنت',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchPlans,
              icon: Icon(
                Icons.refresh,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                'إعادة المحاولة',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد باقات متاحة حالياً',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
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

  Widget _buildPlansList(ThemeData theme) {
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        final isSelected = _selectedPlanId == plan.id;
        final isRecommended = plan.recommended;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : isRecommended
                      ? theme.colorScheme.secondary
                      : Colors.grey.shade300,
              width: isSelected ? 2.5 : isRecommended ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.05)
                : isRecommended
                    ? theme.colorScheme.secondary.withOpacity(0.05)
                    : null,
          ),
          child: InkWell(
            onTap: () => _onPlanSelected(plan.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isRecommended) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'موصى به',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    plan.title,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${plan.durationMonths} ${plan.durationMonths == 1 ? 'شهر' : 'أشهر'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                      Radio<String>(
                        value: plan.id,
                        groupValue: _selectedPlanId,
                        onChanged: (value) => _onPlanSelected(value!),
                        activeColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  if (plan.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      plan.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${_currencySymbol}${plan.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
