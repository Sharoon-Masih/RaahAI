// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cases_provider.dart';
import 'core/providers/dashboard_provider.dart';
import 'core/services/api_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/home/home_shell.dart';

// Global navigator key to allow navigation from the service layer on 401 errors
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RaahAiApp());
}

class RaahAiApp extends StatefulWidget {
  const RaahAiApp({super.key});

  @override
  State<RaahAiApp> createState() => _RaahAiAppState();
}

class _RaahAiAppState extends State<RaahAiApp> {
  @override
  void initState() {
    super.initState();
    // Register the 401 unauthorized redirect callback in ApiService
    ApiService.onUnauthorized = () {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Clear local state first
        Provider.of<AuthProvider>(context, listen: false).logout();
        // Redirect to Login Screen, clearing navigation stack
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..checkAuthStatus(),
        ),
        ChangeNotifierProvider<CasesProvider>(
          create: (_) => CasesProvider(),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'RaahAI',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryAccent,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            error: AppColors.critical,
          ),
          cardTheme: CardThemeData(
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border, width: 1),
            ),
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.background,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: AppTextStyles.heading3(color: AppColors.textPrimary),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            labelStyle: AppTextStyles.bodyMedium(color: AppColors.textMuted),
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.critical),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: AppColors.background,
              textStyle: AppTextStyles.labelMedium(color: AppColors.background, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              textStyle: AppTextStyles.labelMedium(color: AppColors.secondary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeShell(),
        },
        home: const AuthGateway(),
      ),
    );
  }
}

class AuthGateway extends StatelessWidget {
  const AuthGateway({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to AuthProvider's state to determine route
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
              ),
              SizedBox(height: 16),
              Text(
                'Initializing RaahAI...',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (authProvider.isAuthenticated) {
      return const HomeShell();
    }

    return const LoginScreen();
  }
}
