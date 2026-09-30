import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/services/session.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  var _isLoading = false;
  var _email = '';
  var _password = '';
  var _role = Session.role.value;

  bool get _isAdmin => _role == LoginRole.admin;

  void _selectRole(LoginRole role) {
    setState(() {
      _role = role;
      // Admin accounts can't be created from the app, only signed in to.
      if (role == LoginRole.admin) _isLogin = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() { _isLoading = true; });
    // main.dart checks this after sign-in and refuses admin mode for
    // accounts that aren't admins.
    await Session.setRole(_role);
    final auth = FirebaseAuth.instance;
    try {
      if (_isLogin) {
        await auth.signInWithEmailAndPassword(email: _email, password: _password);
      } else {
        await auth.createUserWithEmailAndPassword(email: _email, password: _password);
      }
      // main.dart switches to the app automatically once signed in.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(_messageFor(e))));
      setState(() { _isLoading = false; });
    }
  }

  String _messageFor(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Wrong email or password.',
        'email-already-in-use' => 'An account with this email already exists.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'That email address is not valid.',
        _ => e.message ?? 'Something went wrong. Please try again.',
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<LoginRole>(
            tooltip: 'Choose how to sign in',
            icon: Icon(_isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline),
            iconSize: 30,
            initialValue: _role,
            onSelected: _selectRole,
            itemBuilder: (ctx) => [
              _roleItem(LoginRole.user, Icons.person_outline, 'User'),
              _roleItem(LoginRole.admin, Icons.admin_panel_settings_outlined, 'Admin'),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                Icon(Icons.fastfood, size: 72, color: colors.primary),
                const SizedBox(height: 12),
                Text(
                  'Cooking Up!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Chip(
                  avatar: Icon(
                    _isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                    size: 18,
                  ),
                  label: Text(_isAdmin ? 'Admin sign in' : 'User'),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(labelText: 'Email'),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            validator: (value) =>
                                value == null || !value.contains('@')
                                    ? 'Enter a valid email address.'
                                    : null,
                            onSaved: (value) => _email = value!.trim(),
                          ),
                          TextFormField(
                            decoration: const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                            validator: (value) => value == null || value.length < 6
                                ? 'Password must be at least 6 characters.'
                                : null,
                            onSaved: (value) => _password = value!,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            const CircularProgressIndicator()
                          else ...[
                            FilledButton(
                              onPressed: _submit,
                              child: Text(_isLogin ? 'Sign in' : 'Sign up'),
                            ),
                            if (!_isAdmin)
                              TextButton(
                                onPressed: () => setState(() { _isLogin = !_isLogin; }),
                                child: Text(_isLogin
                                    ? 'New here? Create an account'
                                    : 'Already have an account? Sign in'),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Only accounts made admin by the owner can sign in here.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ],
                      ),
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

  PopupMenuItem<LoginRole> _roleItem(LoginRole role, IconData icon, String label) =>
      PopupMenuItem(
        value: role,
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 18))),
            if (role == _role) const Icon(Icons.check),
          ],
        ),
      );
}
