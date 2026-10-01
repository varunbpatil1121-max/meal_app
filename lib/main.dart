import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meal_app/firebase_options.dart';
import 'package:meal_app/screens/auth_screen.dart';
import 'package:meal_app/screens/tabs_screen.dart';
import 'package:meal_app/services/notification_service.dart';
import 'package:meal_app/services/meal_service.dart';
import 'package:meal_app/services/price_service.dart';
import 'package:meal_app/services/session.dart';
import 'package:meal_app/services/user_service.dart';

final theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: const Color.fromARGB(255, 131, 57, 0),
  ),
  textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Without this, a startup failure leaves a blank white screen.
    runApp(StartupErrorApp(error: e));
    return;
  }
  await Session.load();
  runApp(const App());
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't connect to the server",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final user = snapshot.data;
          if (user == null) return const AuthScreen();
          return SignedInHome(key: ValueKey(user.uid), user: user);
        },
      ),
    );
  }
}

/// Sets up everything a signed-in user needs (profile, meals, live prices,
/// order notifications). Shows the admin view only when the person chose
/// "Admin" on the sign-in screen and their account really is an admin.
class SignedInHome extends StatefulWidget {
  const SignedInHome({super.key, required this.user});

  final User user;

  @override
  State<SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<SignedInHome> {
  bool? _isAdmin; // null until we know the account's role
  StreamSubscription<bool>? _roleSub;

  bool get _wantsAdmin => Session.role.value == LoginRole.admin;

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  Future<void> _setUp() async {
    final uid = widget.user.uid;
    await UserService.ensureUserDoc(widget.user);
    PriceService.start();
    MealService.start();
    NotificationService.startForUser(uid);
    _roleSub = UserService.watchIsAdmin(uid).listen((accountIsAdmin) {
      if (_wantsAdmin && !accountIsAdmin) {
        _rejectAdminSignIn();
        return;
      }
      final isAdmin = _wantsAdmin && accountIsAdmin;
      if (isAdmin) {
        PriceService.seedMissingPrices();
        NotificationService.startForAdmin();
      } else {
        NotificationService.stopAdmin();
      }
      if (mounted) setState(() { _isAdmin = isAdmin; });
    });
  }

  Future<void> _rejectAdminSignIn() async {
    await _roleSub?.cancel();
    await Session.setRole(LoginRole.user);
    await NotificationService.stop();
    await FirebaseAuth.instance.signOut();
    scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
      content: Text('This account is not an admin. Sign in as User instead.'),
    ));
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    PriceService.stop();
    MealService.stop();
    NotificationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    if (isAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return TabsScreen(isAdmin: isAdmin);
  }
}
