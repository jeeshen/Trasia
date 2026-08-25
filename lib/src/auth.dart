part of '../main.dart';

class TrasiaApp extends StatelessWidget {
  const TrasiaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trasia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TrasiaColors.primary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: TrasiaColors.background,
        useMaterial3: true,
        fontFamily: 'Roboto',
        snackBarTheme: _trasiaSnackBarTheme,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _auth = const AuthService();
  bool _loading = false;
  bool _signingUp = false;
  bool _awaitingOtp = false;
  String? _pendingEmail;
  String? _message;
  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isSupabaseReady) {
      unawaited(_resumeSession());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _resumeSession() async {
    if (!SupabaseConfig.isSupabaseReady) return;
    try {
      final profile = await _auth.currentProfile();
      if (mounted && profile != null) {
        _enter(profile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Failed to resume session: $e');
      }
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (!SupabaseConfig.isSupabaseReady) {
      setState(
        () => _message =
            'Supabase is not ready. Check the connection and restart the app.',
      );
      return;
    }
    if (email.isEmpty || password.length < 6) {
      setState(
        () => _message =
            'Enter an email and a password with at least 6 characters.',
      );
      return;
    }
    if (_signingUp && password != confirmPassword) {
      setState(() => _message = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final profile = _signingUp
          ? await _auth.signUp(email: email, password: password)
          : await _auth.signIn(email: email, password: password);
      if (profile == null) {
        if (mounted) {
          setState(() {
            _awaitingOtp = true;
            _pendingEmail = email;
            _message = 'Enter the 6-digit code sent to $email.';
          });
        }
        return;
      }
      if (mounted) {
        _enter(profile);
      }
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } catch (error) {
      setState(() => _message = 'Auth failed: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final email = _pendingEmail;
    final token = _otpController.text.trim();
    if (email == null || !RegExp(r'^\d{6}$').hasMatch(token)) {
      setState(() => _message = 'Enter the 6-digit confirmation code.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final profile = await _auth.verifySignupOtp(email: email, token: token);
      if (mounted) _enter(profile);
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Email confirmation failed: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    final email = _pendingEmail;
    if (email == null) return;
    setState(() => _loading = true);
    try {
      await _auth.resendSignupOtp(email);
      if (mounted) setState(() => _message = 'A new code has been sent.');
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Unable to resend the code: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enter(AuthProfile profile) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) {
          if (profile.role == UserRole.admin) {
            return AdminPanel(profile: profile, onLogout: _logoutFromDashboard);
          }
          return DashboardScreen(
            profile: profile,
            onLogout: _logoutFromDashboard,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _logoutFromDashboard(BuildContext context) async {
    if (SupabaseConfig.isSupabaseReady) {
      await const PushNotificationService().unregister();
      await _auth.signOut();
    }
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _preview(UserRole role) {
    _enter(
      AuthProfile(
        email: role == UserRole.admin
            ? 'preview-admin@trasia.local'
            : 'preview-user@trasia.local',
        role: role,
        credit: 0.0,
        savedTransitRoutes: 14,
        hubPoolTransactions: 6,
        carbonSavedKg: 28.4,
        rewardPoints: 600,
        redeemedVouchers: const [],
        checkedInPlaces: const {},
        favoritePlaces: const [],
        tripHistory: const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF102033);
    const muted = Color(0xFF536477);
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TrasiaColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        snackBarTheme: _trasiaSnackBarTheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FBFF),
          prefixIconColor: muted,
          labelStyle: const TextStyle(
            color: muted,
            fontWeight: FontWeight.w700,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCCD8E6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCCD8E6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: TrasiaColors.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    Center(
                      child: Image.asset(
                        'assets/branding/app_logo.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                        semanticLabel: 'Trasia logo',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'TRASIA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _signingUp ? 'Create an account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _AuthFormPanel(
                      signingUp: _signingUp,
                      awaitingOtp: _awaitingOtp,
                      loading: _loading,
                      message: _message,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      otpController: _otpController,
                      onSubmit: _submit,
                      onVerifyOtp: _verifyOtp,
                      onResendOtp: _resendOtp,
                      onBackToSignUp: _loading
                          ? null
                          : () => setState(() {
                              _awaitingOtp = false;
                              _pendingEmail = null;
                              _otpController.clear();
                              _confirmPasswordController.clear();
                              _message = null;
                            }),
                      onToggleMode: _loading
                          ? null
                          : () => setState(() {
                              _signingUp = !_signingUp;
                              _confirmPasswordController.clear();
                              _message = null;
                            }),
                      onPreviewUser: () => _preview(UserRole.user),
                      onPreviewAdmin: () => _preview(UserRole.admin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.signingUp,
    required this.awaitingOtp,
    required this.loading,
    required this.message,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.otpController,
    required this.onSubmit,
    required this.onVerifyOtp,
    required this.onResendOtp,
    required this.onBackToSignUp,
    required this.onToggleMode,
    required this.onPreviewUser,
    required this.onPreviewAdmin,
  });
  final bool signingUp;
  final bool awaitingOtp;
  final bool loading;
  final String? message;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController otpController;
  final VoidCallback onSubmit;
  final VoidCallback onVerifyOtp;
  final VoidCallback onResendOtp;
  final VoidCallback? onBackToSignUp;
  final VoidCallback? onToggleMode;
  final VoidCallback onPreviewUser;
  final VoidCallback onPreviewAdmin;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _authPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (awaitingOtp) ...[
            const Text(
              'Confirm your email',
              style: TextStyle(
                color: Color(0xFF102033),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use the one-time code from your email to activate your account.',
              style: TextStyle(color: Color(0xFF536477), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('signup-otp'),
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                color: Color(0xFF102033),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                labelText: 'Confirmation code',
                prefixIcon: Icon(Icons.verified_outlined),
                counterText: '',
              ),
              onSubmitted: (_) => onVerifyOtp(),
            ),
          ] else ...[
            TextField(
              key: const Key('login-email'),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: Color(0xFF102033)),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('login-password'),
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: Color(0xFF102033)),
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            if (signingUp) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('signup-confirm-password'),
                controller: confirmPasswordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                style: const TextStyle(color: Color(0xFF102033)),
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Password must be at least 6 characters.',
              style: TextStyle(color: Color(0xFF536477), fontSize: 13),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 14),
            _SheetNotice(message: message!),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: Key(awaitingOtp ? 'signup-verify' : 'login-submit'),
            onPressed: loading
                ? null
                : awaitingOtp
                ? onVerifyOtp
                : onSubmit,
            icon: loading
                ? const TrasiaLoadingCompass(
                    size: 18,
                    semanticLabel: 'Processing',
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(
              awaitingOtp
                  ? 'Confirm email'
                  : signingUp
                  ? 'Sign up'
                  : 'Log in',
            ),
          ),
          if (awaitingOtp) ...[
            TextButton(
              onPressed: loading ? null : onResendOtp,
              child: const Text('Resend code'),
            ),
            TextButton(
              onPressed: onBackToSignUp,
              child: const Text('Use a different email'),
            ),
          ] else
            TextButton(
              onPressed: onToggleMode,
              child: Text(
                signingUp
                    ? 'I already have an account'
                    : 'Create a user account',
              ),
            ),
          if (!SupabaseConfig.isSupabaseReady) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AuthPreviewButton(
                    key: const Key('login-user'),
                    icon: Icons.person_rounded,
                    label: 'Preview user',
                    onTap: onPreviewUser,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AuthPreviewButton(
                    key: const Key('login-admin'),
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Preview admin',
                    onTap: onPreviewAdmin,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthPreviewButton extends StatelessWidget {
  const _AuthPreviewButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: TrasiaColors.primary,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Color(0xFFDCEBFA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

BoxDecoration _authPanelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE4ECF5)),
  );
}
