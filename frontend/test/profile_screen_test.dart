import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/profile/domain/user_profile.dart';
import 'package:frontend/features/profile/presentation/providers/profile_provider.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('renders profile details from provider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async {
            return const UserProfile(
              id: 1,
              name: 'Profile User',
              email: 'profile@example.com',
              avatarPath: null,
              createdAt: '2026-05-02T00:00:00.000Z',
              updatedAt: '2026-05-02T00:00:00.000Z',
            );
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Email: profile@example.com'), findsOneWidget);
    expect(find.text('Save profile'), findsOneWidget);
  });
}
