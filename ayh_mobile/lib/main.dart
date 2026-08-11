import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/donor_provider.dart';
import 'presentation/providers/blood_request_provider.dart';
import 'presentation/providers/notification_provider.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/providers/whatsapp_chat_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'data/services/storage_service.dart';
import 'core/api/api_client.dart';
import 'core/constants/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_launch_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLaunchGate.resetForNewRun();

  await StorageService().init();
  await ApiConstants.loadSavedBaseUrl(StorageService().getApiBaseUrl);
  ApiClient().setBaseUrl(ApiConstants.baseUrl);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DonorProvider()),
        ChangeNotifierProvider(create: (_) => BloodRequestProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => WhatsAppChatProvider()),
      ],
      child: MaterialApp(
        title: 'Blood450',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
