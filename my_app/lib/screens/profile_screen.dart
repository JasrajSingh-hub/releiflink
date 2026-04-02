import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const routeName = '/profile';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final session = AuthService.instance.session;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: session == null
                  ? _LoggedOut(onLogin: () async {
                      final ok = await Navigator.of(context).pushNamed(
                        LoginScreen.routeName,
                      );
                      if (ok == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logged in')),
                        );
                      }
                    })
                  : _LoggedIn(
                      email: session.user.email,
                      role: session.user.role,
                      onLogout: () async {
                        await AuthService.instance.logout();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logged out')),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _LoggedOut extends StatelessWidget {
  const _LoggedOut({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Not signed in',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Login is required to create requests (user) or accept/complete requests (volunteer).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF52525B),
                height: 1.35,
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.login),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('LOGIN'),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoggedIn extends StatelessWidget {
  const _LoggedIn({
    required this.email,
    required this.role,
    required this.onLogout,
  });

  final String email;
  final String role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Signed in',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        _Row(label: 'Email', value: email),
        const SizedBox(height: 10),
        _Row(label: 'Role', value: role),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('LOGOUT'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF71717A),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

