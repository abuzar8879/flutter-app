import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../friends/presentation/screens/my_friends_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../status/presentation/screens/status_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  final List<int> _tabHistory = [0];

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _tabHistory.remove(index);
      _tabHistory.add(index);
    });
  }

  void _handleBackNavigation() {
    if (_tabHistory.length <= 1) return;
    setState(() {
      _tabHistory.removeLast();
      _selectedIndex = _tabHistory.last;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(encryptionBootstrapProvider);

    final session = ref.watch(authControllerProvider).session;
    if (session != null) {
      ref.read(pushNotificationServiceProvider).initialize(session.token);
    }

    const pages = [
      ChatListScreen(),
      StatusScreen(),
      MyFriendsScreen(),
      ProfileScreen(),
    ];

    return PopScope(
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _BottomNavBar(
              selectedIndex: _selectedIndex,
              onSelected: _selectTab,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = const [
      _NavItem(
        index: 0,
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
      ),
      _NavItem(
        index: 1,
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories_rounded,
      ),
      _NavItem(
        index: 2,
        icon: Icons.group_outlined,
        activeIcon: Icons.group_rounded,
      ),
      _NavItem(
        index: 3,
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
      ),
    ];

    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                        : theme.colorScheme.onSurface.withValues(alpha: 0.45),
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
