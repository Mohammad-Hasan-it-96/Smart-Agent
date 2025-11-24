import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'core/db/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/utils/slide_page_route.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/activation/activation_screen.dart';
import 'features/companies/companies_screen.dart';
import 'features/medicines/medicines_screen.dart';
import 'features/pharmacies/pharmacies_screen.dart';
import 'features/orders/new_order_screen.dart';
import 'features/orders/orders_list_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/activation/agent_registration_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  await SharedPreferences.getInstance();

  // Initialize SQLite database
  await DatabaseHelper.instance.database;

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'المندوب الذكي',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // Set RTL direction for Arabic
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [
            Locale('ar', 'SA'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          // Set SplashScreen as initial route
          initialRoute: '/',
          onGenerateRoute: (settings) {
            Widget page;
            SlideDirection direction = SlideDirection.rightToLeft;

            switch (settings.name) {
              case '/':
                return MaterialPageRoute(builder: (_) => const SplashScreen());
              case '/onboarding':
                return MaterialPageRoute(
                    builder: (_) => const OnboardingScreen());
              case '/home':
                page = const HomeScreen();
                break;
              case '/agent-registration':
                page = const AgentRegistrationScreen();
                break;
              case '/activation':
                page = const ActivationScreen();
                break;
              case '/companies':
                page = const CompaniesScreen();
                break;
              case '/medicines':
                page = const MedicinesScreen();
                break;
              case '/pharmacies':
                page = const PharmaciesScreen();
                break;
              case '/orders/create':
                page = const NewOrderScreen();
                break;
              case '/orders':
                page = const OrdersListScreen();
                break;
              case '/settings':
                page = const SettingsScreen();
                break;
              default:
                return MaterialPageRoute(builder: (_) => const HomeScreen());
            }

            return SlidePageRoute(page: page, direction: direction);
          },
        );
      },
    );
  }
}
