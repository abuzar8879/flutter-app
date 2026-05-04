import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/auth_controller.dart';
import '../widgets/login_form.dart';
import '../widgets/signup_form.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authMode = ref.watch(authModeProvider);
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo or Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
                
                const SizedBox(height: 24),
                
                Text(
                  'Chatter',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                
                const SizedBox(height: 8),
                
                Text(
                  authMode == AuthMode.login
                      ? 'Welcome back! Please enter your details.'
                      : 'Create an account to connect with friends.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 40),
                
                // Toggle between Login and Signup
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AuthModeTab(
                          label: 'Login',
                          isSelected: authMode == AuthMode.login,
                          onTap: () => ref.read(authModeProvider.notifier).setMode(AuthMode.login),
                        ),
                      ),
                      Expanded(
                        child: _AuthModeTab(
                          label: 'Signup',
                          isSelected: authMode == AuthMode.signup,
                          onTap: () => ref.read(authModeProvider.notifier).setMode(AuthMode.signup),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
                
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => ref.read(authControllerProvider.notifier).clearError(),
                          color: theme.colorScheme.error,
                        ),
                      ],
                    ),
                  ).animate().shake(),
                ],
                
                const SizedBox(height: 32),
                
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: authMode == AuthMode.login
                      ? const LoginScreen(key: ValueKey('login'))
                      : const SignupScreen(key: ValueKey('signup')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthModeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AuthModeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}
