import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الصفحة الرئيسية'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMenuCard(
            context,
            title: 'الشركات',
            icon: Icons.business,
            onTap: () {
              // Navigate to companies screen
              // Navigator.pushNamed(context, '/companies');
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            title: 'الأدوية',
            icon: Icons.medication,
            onTap: () {
              // Navigate to medicines screen
              // Navigator.pushNamed(context, '/medicines');
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            title: 'الصيدليات',
            icon: Icons.local_pharmacy,
            onTap: () {
              // Navigate to pharmacies screen
              // Navigator.pushNamed(context, '/pharmacies');
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            title: 'إنشاء طلبية جديدة',
            icon: Icons.add_shopping_cart,
            onTap: () {
              // Navigate to create order screen
              // Navigator.pushNamed(context, '/orders/create');
            },
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            title: 'الطلبيات السابقة',
            icon: Icons.history,
            onTap: () {
              // Navigate to orders history screen
              // Navigator.pushNamed(context, '/orders');
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            title: 'الإعدادات',
            icon: Icons.settings,
            onTap: () {
              // Navigate to settings screen
              // Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
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
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 20.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                size: 32,
                color: color ?? Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ),
              const Icon(
                Icons.arrow_back_ios,
                size: 20,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

