import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../friends/presentation/screens/my_friends_screen.dart';
import '../../../friends/presentation/screens/user_discovery_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(encryptionBootstrapProvider);

    final session = ref.watch(authControllerProvider).session;
    if (session != null) {
      ref.read(pushNotificationServiceProvider).initialize(session.token);
    }

    const pages = [
      ChatListScreen(),
      UserDiscoveryScreen(),
      MyFriendsScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _BottomNavBar(
            selectedIndex: _selectedIndex,
            onSelected: (index) => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = const [
      _NavItem(index: 0, icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded),
      _NavItem(index: 1, icon: Icons.person_search_outlined, activeIcon: Icons.person_search_rounded),
      _NavItem(index: 2, icon: Icons.group_outlined, activeIcon: Icons.group_rounded),
      _NavItem(index: 3, icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
    ];

    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final selected = item.index == selectedIndex;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSelected(item.index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.45),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: selected ? 6 : 0,
                    height: selected ? 6 : 0,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}


class _NavItem {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
  });

  final int index;
  final IconData icon;
  final IconData activeIcon;
}
