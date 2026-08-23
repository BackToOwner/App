import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:back_to_owner/models/report_item.dart';
import 'package:back_to_owner/screens/report_list_screen.dart';
import 'package:back_to_owner/services/auth/mock_auth_service.dart';
import 'package:back_to_owner/services/filter/report_filter_strategy.dart';
import 'package:back_to_owner/services/repository/in_memory_report_repository.dart';
import 'package:back_to_owner/services/repository/report_repository_interface.dart';
import 'package:back_to_owner/viewmodels/auth_viewmodel.dart';
import 'package:back_to_owner/viewmodels/dashboard_viewmodel.dart';
import 'package:back_to_owner/widgets/custom_segmented_control.dart';
import 'package:back_to_owner/widgets/empty_state_widget.dart';
import 'package:back_to_owner/widgets/section_header.dart';

void main() {
  group('SOLID Architecture Unit Tests', () {
    test('MockAuthService satisfies IAuthService contract (LSP, SRP)', () async {
      final authService = MockAuthService();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUserEmail, isNull);

      final result = await authService.signIn('test@example.com', 'password123');
      expect(result, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUserEmail, equals('test@example.com'));

      await authService.signOut();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUserEmail, isNull);
    });

    test('InMemoryReportRepository manages report operations (ISP, DIP, LSP)', () {
      final repository = InMemoryReportRepository([]);
      expect(repository.getAllReports(), isEmpty);

      final item1 = ReportItem(
        id: '101',
        title: 'Lost Wallet',
        location: 'Downtown',
        type: ReportType.lost,
        timeAgo: '1h ago',
        emojiIcon: '👛',
        iconBgHex: 'FFF0F5',
      );

      final item2 = ReportItem(
        id: '102',
        title: 'Found Keys',
        location: 'Uptown',
        type: ReportType.found,
        timeAgo: '30m ago',
        emojiIcon: '🔑',
        iconBgHex: 'F0FDF4',
      );

      repository.addReport(item1);
      repository.addReport(item2);

      expect(repository.getAllReports().length, equals(2));
      expect(repository.getLostReports().length, equals(1));
      expect(repository.getFoundReports().length, equals(1));

      repository.deleteReport('101');
      expect(repository.getAllReports().length, equals(1));
      expect(repository.getAllReports().first.id, equals('102'));
    });

    test('ReportFilterStrategy implements OCP correctly', () {
      final itemLost = ReportItem(
        id: '1',
        title: 'Black Leather Wallet',
        location: 'Central Park',
        type: ReportType.lost,
        timeAgo: '10m ago',
        emojiIcon: '👛',
        iconBgHex: 'FFF0F5',
      );

      final itemFound = ReportItem(
        id: '2',
        title: 'iPhone 15',
        location: 'Central Station',
        type: ReportType.found,
        timeAgo: '5m ago',
        emojiIcon: '📱',
        iconBgHex: 'F0F7FF',
      );

      final items = [itemLost, itemFound];

      final allFilter = AllReportsFilterStrategy();
      final lostFilter = LostReportsFilterStrategy();
      final foundFilter = FoundReportsFilterStrategy();

      expect(allFilter.filter(items, ''), hasLength(2));
      expect(lostFilter.filter(items, ''), hasLength(1));
      expect(foundFilter.filter(items, ''), hasLength(1));

      // Test search query matching
      expect(allFilter.filter(items, 'Wallet'), hasLength(1));
      expect(allFilter.filter(items, 'Central'), hasLength(2));
      expect(allFilter.filter(items, 'Nonexistent'), isEmpty);
    });

    test('AuthViewModel delegates to injected IAuthService (DIP, SRP)', () async {
      final mockAuth = MockAuthService();
      final viewModel = AuthViewModel(mockAuth);

      expect(viewModel.isSignIn, isTrue);
      expect(viewModel.obscurePassword, isTrue);

      viewModel.setAuthMode(false);
      expect(viewModel.isSignIn, isFalse);

      viewModel.togglePasswordVisibility();
      expect(viewModel.obscurePassword, isFalse);
    });

    test('DashboardViewModel delegates to injected IReportRepository and Filter Strategy', () {
      final repository = InMemoryReportRepository([]);
      final viewModel = DashboardViewModel(repository);

      expect(viewModel.allReports, isEmpty);

      final item = ReportItem(
        id: '1',
        title: 'AirPods',
        location: 'Library',
        type: ReportType.found,
        timeAgo: '1h ago',
        emojiIcon: '🎧',
        iconBgHex: 'F0F7FF',
      );

      viewModel.addReport(item);
      expect(viewModel.allReports, hasLength(1));
      expect(viewModel.filteredReports, hasLength(1));

      viewModel.setFilter(ReportType.lost);
      expect(viewModel.filteredReports, isEmpty);

      viewModel.setFilter(ReportType.found);
      expect(viewModel.filteredReports, hasLength(1));
    });
  });

  group('DRY Components & Widget Render Tests', () {
    testWidgets('EmptyStateWidget renders correctly with title and button', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              emoji: '🔍',
              title: 'No Data Available',
              subtitle: 'Try adding a new record.',
              buttonLabel: 'Add Record',
              badgeBgColor: Colors.blue,
              buttonBgColor: Colors.green,
              onButtonPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('No Data Available'), findsOneWidget);
      expect(find.text('Add Record'), findsOneWidget);

      await tester.tap(find.text('Add Record'));
      expect(pressed, isTrue);
    });

    testWidgets('SectionHeader renders title and action label', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Featured Items',
              actionLabel: 'View All',
              onActionTap: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Featured Items'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      await tester.tap(find.text('View All'));
      expect(actionTapped, isTrue);
    });

    testWidgets('CustomSegmentedControl allows toggling options', (tester) async {
      bool selected = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSegmentedControl<bool>(
              options: const [
                SegmentedOption(value: true, label: 'Option A'),
                SegmentedOption(value: false, label: 'Option B'),
              ],
              selectedValue: selected,
              onValueChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);

      await tester.tap(find.text('Option B'));
      expect(selected, isFalse);
    });

    testWidgets('ReportListScreen renders consolidated Lost/Found lists', (tester) async {
      final repository = InMemoryReportRepository([
        ReportItem(
          id: '1',
          title: 'Lost Keys',
          location: 'Main St',
          type: ReportType.lost,
          timeAgo: '1h ago',
          emojiIcon: '🔑',
          iconBgHex: 'FFF0F5',
        ),
      ]);

      await tester.pumpWidget(
        ListenableProvider<IReportRepository>.value(
          value: repository,
          child: ChangeNotifierProvider(
            create: (_) => DashboardViewModel(repository),
            child: const MaterialApp(
              home: ReportListScreen(reportType: ReportType.lost),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Lost Items 🥹'), findsOneWidget);
      expect(find.text('Lost Keys'), findsOneWidget);
    });
  });
}
