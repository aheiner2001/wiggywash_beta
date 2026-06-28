import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/manager_auth_screen.dart';
import 'screens/manager_screen.dart';
import 'screens/scorecard_screen.dart';
import 'screens/site_code_screen.dart';
import 'screens/super_admin_screen.dart';
import 'services/store.dart';
import 'theme.dart';
import 'widgets/brand_header.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to Firebase. Employees use a silent anonymous session; managers use
  // Google. If Firebase can't initialize the app still boots.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase unavailable: $e');
  }
  await Store.instance.init();
  runApp(const WiggyWashApp());
}

class WiggyWashApp extends StatelessWidget {
  const WiggyWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wiggy Wash',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

/// Routes by the Store's current view, rebuilding on every change.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        switch (store.view) {
          case AppView.loading:
            return const _Splash();
          case AppView.landing:
            return const SiteCodeScreen();
          case AppView.managerAuth:
            return const ManagerAuthScreen();
          case AppView.employee:
            return ScorecardScreen(profile: store.profile!);
          case AppView.manager:
            return const ManagerScreen();
          case AppView.superAdmin:
            return const SuperAdminScreen();
        }
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandHeader(),
            SizedBox(height: 28),
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
