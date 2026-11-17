import 'package:flutter/material.dart';

import 'home_shell.dart';
import 'notification_service.dart';
import 'splash.dart';
import 'theme.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

Future<void> _initApp() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
      .timeout(const Duration(seconds: 15));

  // Notifications are optional, so a failure here won't block the app.
  try {
    await NotificationService.init().timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  // The saved Light / Dark / System choice, before the app first draws.
  await loadThemeMode();

  // Load the Nunito weights the splash and app use, so text doesn't swap
  // fonts mid-animation. Skipped (fallback font) if offline on first run.
  try {
    for (final w in [
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ]) {
      appFont(fontWeight: w);
    }
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('Font preload skipped: $e');
  }
}

/// Startup: plain forest green (matching the launch screen) while Firebase,
/// notifications and the font load; then the full logo animation; then
/// the app. Playing the animation after the heavy work keeps it smooth and
/// complete instead of half-skipped by launch stutter.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  bool _ready = false;
  bool _introDone = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initApp().then(
      (_) {
        if (mounted) setState(() => _ready = true);
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text('Startup error:\n\n$_error'),
              ),
            ),
          ),
        ),
      );
    }
    if (!_ready || !_introDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BrandSplash(
          start: _ready,
          onFinished: () => setState(() => _introDone = true),
        ),
      );
    }
    return const FridgeMateApp();
  }
}

/// "Fridge Mate" in the app's heavy rounded type, with "by ShelfLife"
/// underneath. Stands in until the Fridge Mate logo is chosen.
class FridgeMateWordmark extends StatelessWidget {
  final Color color;
  final double size;
  const FridgeMateWordmark({
    super.key,
    this.color = Colors.white,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FridgeMateIcon(size: size * 2),
      SizedBox(height: size * 0.35),
      Text(
        'Fridge Mate',
        style: appFont(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'by',
            style: appFont(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w700,
              color: color == Colors.white ? forestLight : mutedText,
            ),
          ),
          const SizedBox(width: 2),
          ShelfLifeLogo(height: size * 0.8),
        ],
      ),
    ],
  );
}

class FridgeMateApp extends StatelessWidget {
  const FridgeMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the user picks System / Light / Dark in their profile.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeSetting,
      builder: (context, mode, _) => MaterialApp(
        title: 'Fridge Mate',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: mode,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Same screen the animation ended on, so there's no flash.
              return const BrandSplash(playIntro: false);
            }
            if (snapshot.hasData) return const HomeShell();
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_isRegister) {
        await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                  decoration: BoxDecoration(
                    color: context.palette.hero,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(child: FridgeMateWordmark(size: 38)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Save money, reduce waste',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_isRegister ? 'Create account' : 'Sign in'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account',
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
