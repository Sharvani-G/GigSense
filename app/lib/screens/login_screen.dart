import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'playful_widgets.dart';
import '../i18n/strings.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onBypass;
  const LoginScreen({super.key, this.onBypass});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updateState);
    _passwordController.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // Sign up password requirements:
        // - At least 8 characters long
        // - Contain at least one special character
        final errors = <String>[];
        if (password.length < 8) {
          errors.add("Password must be at least 8 characters long.");
        }
        final hasSpecial = password.contains(RegExp(r'[!@#\$%^&\*\(\)_\+\-=\[\]\{\};:\x27",\.<>\?\/\\\|~`]'));
        if (!hasSpecial) {
          errors.add("Password must contain at least one special character.");
        }

        if (errors.isNotEmpty) {
          setState(() {
            _errorMessage = errors.join("\n");
            _isLoading = false;
          });
          return;
        }

        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Auth Error: ${e.code} - ${e.message}");
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e);
      });
    } catch (e) {
      debugPrint("Unknown Auth Error: $e");
      setState(() {
        _errorMessage = "Something went wrong. Please check your connection.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint("Guest Sign In Error: $e");
      if (widget.onBypass != null) {
        widget.onBypass!();
      } else {
        setState(() {
          _errorMessage = "Failed to sign in as guest. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email address to reset password.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _errorMessage = "Password reset email sent! Check your inbox.";
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Must be at least 6 characters.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    final bool canSubmit = _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        !_isLoading;

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Wordmark
                Text(
                  s.t('app_name'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: 2.0,
                    color: PlayfulColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                Text(
                  s.t('tagline'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: PlayfulColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 36),

                // Login/Signup Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PlayfulColors.border, width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isLogin = true;
                            _errorMessage = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isLogin ? PlayfulColors.accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: _isLogin ? Border.all(color: PlayfulColors.border, width: 2) : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.t('login'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _isLogin ? Colors.white : PlayfulColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isLogin = false;
                            _errorMessage = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isLogin ? PlayfulColors.accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: !_isLogin ? Border.all(color: PlayfulColors.border, width: 2) : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.t('signup'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: !_isLogin ? Colors.white : PlayfulColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Email Input
                PlayfulInput(
                  labelText: s.t('email_address'),
                  hintText: "driver@gigly.com",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                // Password Input
                PlayfulInput(
                  labelText: s.t('password'),
                  hintText: "••••••••",
                  controller: _passwordController,
                  obscureText: true,
                ),
                if (_isLogin) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: Text(
                        s.t('forgot_password'),
                        style: GoogleFonts.plusJakartaSans(
                          color: PlayfulColors.mutedForeground,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                ],

                // Error text placeholder (soft, not red popup)
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: PlayfulColors.mutedForeground,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action button
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: PlayfulColors.accent),
                  )
                else
                  PlayfulButton(
                    onPressed: canSubmit ? _submit : null,
                    child: Text(_isLogin ? s.t('btn_login') : s.t('btn_create_account')),
                  ),

                const SizedBox(height: 24),

                // Continue as guest
                TextButton(
                  onPressed: _isLoading ? null : _signInAsGuest,
                  child: Text(
                    s.t('continue_as_guest'),
                    style: GoogleFonts.plusJakartaSans(
                      color: PlayfulColors.mutedForeground,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
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
