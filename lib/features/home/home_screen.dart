import 'package:flutter/material.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/utils/slide_page_route.dart';
import '../companies/companies_screen.dart';
import '../medicines/medicines_screen.dart';
import '../pharmacies/pharmacies_screen.dart';
import '../orders/new_order_screen.dart';
import '../orders/orders_list_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'الصفحة الرئيسية'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildMenuCard(
              context,
              title: 'الشركات',
              icon: Icons.business,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(
                    page: const CompaniesScreen(),
                    direction: SlideDirection.rightToLeft,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              title: 'الأدوية',
              icon: Icons.medication,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(
                    page: const MedicinesScreen(),
                    direction: SlideDirection.rightToLeft,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              title: 'الصيدليات',
              icon: Icons.local_pharmacy,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(
                    page: const PharmaciesScreen(),
                    direction: SlideDirection.rightToLeft,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              title: 'إنشاء طلبية جديدة',
              icon: Icons.add_shopping_cart,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(
                    page: const NewOrderScreen(),
                    direction: SlideDirection.rightToLeft,
                  ),
                );
              },
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              title: 'الطلبيات السابقة',
              icon: Icons.history,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(
                    page: const OrdersListScreen(),
                    direction: SlideDirection.rightToLeft,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              title: 'الإعدادات',
              icon: Icons.settings,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(
                    page: const SettingsScreen(),
                    direction: SlideDirection.rightToLeft,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (color ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color ?? theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ),
              Icon(
                Icons.arrow_back_ios,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
