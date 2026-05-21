import 'dart:async';

import 'package:bayangida_logistics/providers/tracking-provider.dart';
import 'package:bayangida_logistics/providers/user_provider.dart';
import 'package:bayangida_logistics/splash/splash-screen2.dart';
import 'package:bayangida_logistics/splash/splashscreen3.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'login/authselect.dart';
import 'logistics/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://klncjtquenfsgekwccet.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtsbmNqdHF1ZW5mc2dla3djY2V0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ2NjY0MzEsImV4cCI6MjA2MDI0MjQzMX0.XSEAADF3ZKiktubM4Eg6dwKSGHHphDeDDH9FF4_FnCI',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bayangida-user',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,

    );
  }
}






class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final StreamSubscription<User?> _authSubscription;
  bool _showLogo = true;
  bool _showOnboarding = false;
  bool _checkingOnboardingStatus = true;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Initialize auth listener and onboarding check
    _initializeAuthFlow(userProvider);
  }

  Future<void> _initializeAuthFlow(UserProvider userProvider) async {
    // Set up auth state listener
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && userProvider.user != null) {
        userProvider.clearUser(); // User signed out
      } else if (user != null && userProvider.user == null) {
        userProvider.setUser(user); // User signed in
      }
    });

    // Check onboarding status
    await _checkOnboardingStatus(userProvider);
  }

  Future<void> _checkOnboardingStatus(UserProvider userProvider) async {
    final hasCompletedOnboarding = await PreferencesService.isOnboardingCompleted();

    // Hide logo after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showLogo = false;
          _checkingOnboardingStatus = false;
          // Show onboarding only if user is new and hasn't completed it
          _showOnboarding = userProvider.user == null && !hasCompletedOnboarding;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (_checkingOnboardingStatus || userProvider.isLoading) {
      return const Logoscreen();
    }

    if (_showLogo) {
      return const Logoscreen();
    }

    if (_showOnboarding) {
      return SplashScreen(
        onCompleted: () async {
          await PreferencesService.setOnboardingCompleted(true);
          if (mounted) {
            setState(() {
              _showOnboarding = false;
            });
          }
        },
      );
    }

    return userProvider.user == null ?  Authselect() :  WelcomeDashboardPage();
  }
}

class PreferencesService {
  static const _keyOnboardingCompleted = 'onboarding_completed';

  static Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, completed);
  }

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }
}
//https://www.figma.com/design/PZ6DHLhXbo4PAUXgkxpowT/Bayangida-App-UIUX?node-id=1317-37830&t=yG3jtSUoTc04nxD9-4
//https://www.figma.com/design/PZ6DHLhXbo4PAUXgkxpowT/Bayangida-App-UIUX?node-id=1317-42555&t=yG3jtSUoTc04nxD9-4
//https://www.figma.com/design/PZ6DHLhXbo4PAUXgkxpowT/Bayangida-App-UIUX?node-id=951-32760&t=yG3jtSUoTc04nxD9-4
//https://www.figma.com/design/PZ6DHLhXbo4PAUXgkxpowT/Bayangida-App-UIUX?node-id=1718-5552&t=yG3jtSUoTc04nxD9-4
//https://www.figma.com/design/PZ6DHLhXbo4PAUXgkxpowT/Bayangida-App-UIUX?node-id=1516-4848&t=yG3jtSUoTc04nxD9-4
//https://www.figma.com/design/PZ6DHLhXbo4PAUXgkxpowT/Bayangida-App-UIUX?node-id=1374-1137&t=yG3jtSUoTc04nxD9-4
//https://www.figma.com/design/PZ6DHLhXbo4PAUXgkxpowT/Bayangida-App-UIUX?node-id=1733-2044&t=yG3jtSUoTc04nxD9-4
// Update the StatCard widget

// Update the ActiveDeliverySection container

// Update the EarningsSection container