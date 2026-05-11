import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../system_status/presentation/screens/system_status_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  bool _isEditing = false;
  String _lastSyncedName = '';
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_isEditing || _isSaving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      return;
    }
    final nextName = _nameController.text.trim();
    if (nextName == _lastSyncedName.trim()) {
      setState(() {
        _isEditing = false;
        _message = 'No profile changes to save.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .updateMyProfile(token: session.token, name: nextName);
      _syncAuthUser(profile);
      ref.invalidate(profileProvider);
      setState(() {
        _nameController.text = profile.name;
        _nameController.selection = TextSelection.collapsed(
          offset: _nameController.text.length,
        );
        _lastSyncedName = profile.name;
        _isEditing = false;
        _message = 'Profile updated successfully.';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (!_isEditing || _isSaving) {
      _showSnack('Tap Edit to change your profile photo.');
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final profile = await ref
          .read(profileRepositoryProvider)
          .uploadMyAvatar(
            token: session.token,
            fileName: file.name,
            bytes: bytes,
          );
      _syncAuthUser(profile);
      ref.invalidate(profileProvider);
      setState(() {
        _lastSyncedName = profile.name;
        _message = 'Profile image uploaded successfully.';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _syncAuthUser(UserProfile profile) {
    ref
        .read(authControllerProvider.notifier)
        .updateCurrentUser(
          AuthUser(
            id: profile.id,
            name: profile.name,
            email: profile.email,
            avatarPath: profile.avatarPath,
            publicKey: ref.read(authControllerProvider).session?.user.publicKey,
          ),
        );
  }

  void _enterEditMode(UserProfile user) {
    setState(() {
      _isEditing = true;
      _message = null;
      _nameController.text = user.name;
      _nameController.selection = TextSelection.collapsed(
        offset: _nameController.text.length,
      );
    });
  }

  void _cancelEditing(UserProfile user) {
    setState(() {
      _isEditing = false;
      _message = null;
      _nameController.text = user.name;
      _nameController.selection = TextSelection.collapsed(
        offset: _nameController.text.length,
      );
      _lastSyncedName = user.name;
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final currentProfile = profile.asData?.value;
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              ref
                  .read(themeModeProvider.notifier)
                  .setMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_isEditing) ...[
            TextButton(
              onPressed: currentProfile == null
                  ? null
                  : () => _cancelEditing(currentProfile),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ] else if (currentProfile != null)
            TextButton(
              onPressed: () => _enterEditMode(currentProfile),
              child: const Text(
                'Edit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: profile.when(
        data: (user) {
          if (!_isEditing && _lastSyncedName != user.name) {
            _nameController.text = user.name;
            _lastSyncedName = user.name;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            width: 4,
                          ),
                        ),
                        child: _buildAvatar(user, theme),
                      ),
                      GestureDetector(
                        onTap: (_isEditing && !_isSaving)
                            ? _pickAndUploadImage
                            : null,
                        child: Opacity(
                          opacity: _isEditing ? 1 : 0.5,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isEditing
                                  ? Icons.camera_alt_rounded
                                  : Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (_isEditing
                                  ? theme.colorScheme.primary
                                  : theme.dividerColor)
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _isEditing
                          ? 'Edit mode'
                          : 'View mode (tap Edit to make changes)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isEditing
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _message!.contains('successfully')
                            ? Colors.green.withOpacity(0.1)
                            : theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _message!.contains('successfully')
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: _message!.contains('successfully')
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _message!.contains('successfully')
                                    ? Colors.green
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildProfileField(
                    label: 'Display Name',
                    controller: _nameController,
                    icon: Icons.person_outline_rounded,
                    enabled: _isEditing && !_isSaving,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildReadOnlyField(
                    label: 'Email Address',
                    value: user.email,
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildReadOnlyField(
                    label: 'Public Key',
                    value: user.publicKey ?? 'Not generated yet',
                    icon: Icons.key_rounded,
                    isMonospaced: true,
                  ),
                  const SizedBox(height: 40),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SystemStatusScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.dns_rounded),
                    label: const Text('Backend System Status'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withOpacity(0.2),
                      ),
                    ),
                    child: const Text('Log Out'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }

  Widget _buildAvatar(UserProfile user, ThemeData theme) {
    final trimmedName = user.name.trim();
    final initial = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();
    if (user.avatarPath != null && user.avatarPath!.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundImage: NetworkImage(
          '${AppConfig.apiBaseUrl}${user.avatarPath}',
        ),
      );
    }
    return CircleAvatar(
      radius: 60,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      child: Text(
        initial,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: 'Enter $label',
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    bool isMonospaced = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.dividerColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontFamily: isMonospaced ? 'monospace' : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
