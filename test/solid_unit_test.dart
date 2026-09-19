import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:back_to_owner/models/app_user.dart';
import 'package:back_to_owner/models/report_item.dart';
import 'package:back_to_owner/screens/report_list_screen.dart';
import 'package:back_to_owner/services/api/api_exception.dart';
import 'package:back_to_owner/services/auth/auth_service_interface.dart';
import 'package:back_to_owner/services/filter/report_filter_strategy.dart';
import 'package:back_to_owner/services/repository/report_repository_interface.dart';
import 'package:back_to_owner/controllers/auth_controller.dart';
import 'package:back_to_owner/controllers/dashboard_controller.dart';
import 'package:back_to_owner/widgets/custom_segmented_control.dart';
import 'package:back_to_owner/widgets/empty_state_widget.dart';
import 'package:back_to_owner/widgets/section_header.dart';

/// Stands in for the real service so the controllers can be tested without a server.
/// Unlike the MockAuthService it replaces, it actually checks the password — the old mock
/// returned true for any input, which is why an empty password used to sign a user in.
class FakeAuthService implements IAuthService {
  static const validEmail = 'test@example.com';
  static const validPassword = 'password123';

  AppUser? _user;
  int signInCalls = 0;

  @override
  bool get isAuthenticated => _user != null;

  @override
  AppUser? get currentUser => _user;

  @override
  String? get currentUserEmail => _user?.email;

  @override
  Future<AppUser> signIn(String email, String password) async {
    signInCalls++;
    if (email != validEmail || password != validPassword) {
      throw const ApiException('Invalid email or password', statusCode: 401);
    }
    return _user = const AppUser(
      id: 'USR-1',
      name: 'Test User',
      firstName: 'Test',
      lastName: 'User',
      email: validEmail,
    );
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? idVerificationNo,
  }) async {
    if (password.length < 8) throw const ApiException('Password must be at least 8 characters.');
    return _user = AppUser(id: 'USR-2', name: '$firstName $lastName', firstName: firstName ?? '', lastName: lastName ?? '', email: email);
  }

  @override
  Future<AppUser> signInWithGoogle() async => throw const ApiException('Not configured');

  @override
  Future<AppUser?> restoreSession() async => _user;

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<String?> requestPasswordReset(String email) async => '123456';

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {}
}

/// In-memory stand-in for the API-backed repository.
class FakeReportRepository extends ValueNotifier<List<ReportItem>> implements IReportRepository {
  FakeReportRepository([List<ReportItem>? initial]) : super(initial ?? const []);

  int refreshCalls = 0;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  List<ReportItem> getAllReports() => List.unmodifiable(value);

  @override
  List<ReportItem> getLostReports() =>
      List.unmodifiable(value.where((i) => i.type == ReportType.lost));

  @override
  List<ReportItem> getFoundReports() =>
      List.unmodifiable(value.where((i) => i.type == ReportType.found));

  @override
  List<ReportItem> getMyReports() => List.unmodifiable(value.where((i) => i.isMine));

  @override
  Future<void> refresh() async => refreshCalls++;

  @override
  Future<ReportItem> addReport({
    required String title,
    required ReportType type,
    required String campus,
    required String area,
    String? itemColor,
    String? additionalDetails,
    String? description,
    String? category,
    double? reward,
    double? lat,
    double? lng,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final item = ReportItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      campus: campus,
      area: area,
      itemColor: itemColor,
      additionalDetails: additionalDetails,
      category: category ?? 'other',
      type: type,
      rewardAmount: reward,
      isMine: true,
      createdAt: DateTime.now(),
    );
    value = [item, ...value];
    return item;
  }

  @override
  Future<void> deleteReport(String id) async {
    value = value.where((i) => i.id != id).toList();
  }
}

ReportItem _item({
  required String id,
  required String title,
  required ReportType type,
  String campus = 'BCI',
  String area = 'Somewhere',
  bool isMine = false,
}) =>
    ReportItem(
      id: id,
      title: title,
      campus: campus,
      area: area,
      type: type,
      isMine: isMine,
      createdAt: DateTime.now(),
    );

void main() {
  group('Auth', () {
    test('a wrong password is rejected instead of silently succeeding', () async {
      final auth = FakeAuthService();
      expect(auth.isAuthenticated, isFalse);

      await expectLater(
        auth.signIn(FakeAuthService.validEmail, 'wrong-password'),
        throwsA(isA<ApiException>()),
      );
      expect(auth.isAuthenticated, isFalse);

      final user = await auth.signIn(FakeAuthService.validEmail, FakeAuthService.validPassword);
      expect(user.email, FakeAuthService.validEmail);
      expect(auth.isAuthenticated, isTrue);

      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
    });

    test('an empty password never reaches the network', () async {
      final auth = FakeAuthService();
      final controller = AuthController(auth)
        ..emailController.text = FakeAuthService.validEmail
        ..passwordController.text = '';

      // Validation happens before the call, so the service is never asked.
      expect(await controller.submitAuth(_DummyContext()), isNull);
      expect(auth.signInCalls, 0);
      expect(controller.errorMessage, 'Please enter your password.');
    });

    test('a malformed email is caught locally', () async {
      final auth = FakeAuthService();
      final controller = AuthController(auth)
        ..emailController.text = 'not-an-email'
        ..passwordController.text = 'password123';

      expect(await controller.submitAuth(_DummyContext()), isNull);
      expect(auth.signInCalls, 0);
      expect(controller.errorMessage, contains('valid email'));
    });

    test('a rejected sign-in surfaces the server message', () async {
      final auth = FakeAuthService();
      final controller = AuthController(auth)
        ..emailController.text = FakeAuthService.validEmail
        ..passwordController.text = 'wrong-password';

      expect(await controller.submitAuth(_DummyContext()), isNull);
      expect(auth.signInCalls, 1);
      expect(controller.errorMessage, 'Invalid email or password');
    });

    test('sign-up enforces the 8 character minimum the server requires', () async {
      final auth = FakeAuthService();
      final controller = AuthController(auth)
        ..setAuthMode(false)
        ..emailController.text = 'new@example.com'
        ..passwordController.text = 'short';

      expect(await controller.submitAuth(_DummyContext()), isNull);
      expect(controller.errorMessage, contains('at least 8 characters'));
    });
  });

  group('ReportItem parsing', () {
    test('builds from an API payload', () {
      final item = ReportItem.fromJson({
        'id': 'LST-1',
        'title': 'Leather Wallet',
        'type': 'lost',
        'status': 'open',
        'location': 'BCI · CRK 2',
        'campus': 'BCI',
        'area': 'CRK 2',
        'itemColor': 'Black',
        'additionalDetails': 'Near the computers on the second floor',
        'category': 'wallets',
        'emoji': '👛',
        'iconBgHex': 'FFF0F5',
        'reward': 5000,
        'rewardCurrency': 'LKR',
        'coordinates': {'lat': 6.9, 'lng': 79.8},
        'images': ['http://x/a.jpg'],
        'owner': {'id': 'USR-1', 'name': 'Ahmed'},
        'isMine': true,
        'viewCount': 3,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      expect(item.id, 'LST-1');
      expect(item.type, ReportType.lost);
      expect(item.emojiIcon, '👛');
      expect(item.ownerName, 'Ahmed');
      expect(item.isMine, isTrue);
      expect(item.lat, 6.9);
      expect(item.viewCount, 3);

      // The campus/area split main added, round-tripped through the API.
      expect(item.campus, 'BCI');
      expect(item.area, 'CRK 2');
      expect(item.location, 'BCI · CRK 2');
      expect(item.displayTitle, 'Black Leather Wallet');
      expect(item.locationFull, contains('second floor'));
    });

    test('survives a payload with missing optional fields', () {
      final item = ReportItem.fromJson({'id': 'X', 'type': 'found'});
      expect(item.title, '');
      expect(item.type, ReportType.found);
      expect(item.emojiIcon, '📦');
      expect(item.reward, isNull);
      expect(item.images, isEmpty);
      expect(item.campus, isEmpty);
      expect(item.itemColor, isNull);
      // No colour means the title is shown as-is, not with a stray leading space.
      expect(item.displayTitle, '');
    });

    test('falls back to the server location when there is no campus or area', () {
      // Reports the admin dashboard filed only ever have the single location string.
      final item = ReportItem.fromJson({
        'id': 'ADM-1',
        'type': 'lost',
        'location': 'Viharamahadevi Park, Colombo',
      });
      expect(item.location, 'Viharamahadevi Park, Colombo');

      final blank = ReportItem.fromJson({'id': 'ADM-2', 'type': 'lost'});
      expect(blank.location, 'Unknown Location');
    });

    test('composes the location the API stores from campus and area', () {
      expect(ReportItem.composeLocation('BCI', 'CRK 2'), 'BCI · CRK 2');
      expect(ReportItem.composeLocation('BCI', ''), 'BCI');
      expect(ReportItem.composeLocation('', ''), isEmpty);
    });

    test('maps the server category to a Material icon', () {
      expect(ReportItem.iconForCategory('wallets'), Icons.account_balance_wallet);
      expect(ReportItem.iconForCategory('electronics'), Icons.smartphone);
      // A category added server-side later must not draw nothing.
      expect(ReportItem.iconForCategory('not-a-real-category'), Icons.inventory_2);
    });

    test('formats a reward, and omits it when there is none', () {
      expect(
        ReportItem.fromJson({'id': 'A', 'type': 'lost', 'reward': 5000, 'rewardCurrency': 'LKR'}).reward,
        'LKR 5,000 reward',
      );
      expect(ReportItem.fromJson({'id': 'B', 'type': 'lost'}).reward, isNull);
      expect(ReportItem.fromJson({'id': 'C', 'type': 'lost', 'reward': 0}).reward, isNull);
    });

    test('computes relative time on the device', () {
      final now = DateTime.now();
      String ago(Duration d) => ReportItem(
            id: 'X',
            title: 't',
            campus: 'BCI',
            area: 'CRK 1',
            type: ReportType.lost,
            createdAt: now.subtract(d),
          ).timeAgo;

      expect(ago(const Duration(seconds: 5)), 'Just now');
      expect(ago(const Duration(minutes: 30)), '30m ago');
      expect(ago(const Duration(hours: 5)), '5h ago');
      expect(ago(const Duration(days: 1)), 'Yesterday');
      expect(ago(const Duration(days: 3)), '3d ago');
    });

    test('only badges states worth calling out', () {
      ReportItem withStatus(String? s) => ReportItem(
            id: 'X',
            title: 't',
            campus: 'BCI',
            area: 'CRK 1',
            type: ReportType.lost,
            status: s,
          );

      expect(withStatus('matched').statusLabel, 'MATCHED');
      expect(withStatus('returned').statusLabel, 'RETURNED');
      expect(withStatus('open').statusLabel, isNull);
    });
  });

  group('Repository and controller (ISP, DIP, LSP)', () {
    test('reads, writes and separates the caller\'s own reports', () async {
      final repository = FakeReportRepository();
      expect(repository.getAllReports(), isEmpty);

      await repository.addReport(
          title: 'Lost Wallet', type: ReportType.lost, campus: 'BCI', area: 'Downtown');
      await repository.addReport(
          title: 'Found Keys', type: ReportType.found, campus: 'BCI', area: 'Park');
      repository.value = [
        ...repository.value,
        _item(id: 'other', title: 'Someone else\'s', type: ReportType.lost),
      ];

      expect(repository.getAllReports().length, 3);
      expect(repository.getLostReports().length, 2);
      expect(repository.getFoundReports().length, 1);
      // My Reports must exclude other people's, which the old screen did not do.
      expect(repository.getMyReports().length, 2);

      await repository.deleteReport(repository.getAllReports().first.id);
      expect(repository.getAllReports().length, 2);
    });

    test('the controller notifies listeners when the repository changes', () async {
      final repository = FakeReportRepository();
      final controller = DashboardController(repository);

      var notified = 0;
      controller.addListener(() => notified++);

      await controller.addReport(
          title: 'New', type: ReportType.lost, campus: 'BCI', area: 'Here');
      expect(notified, greaterThan(0));
      expect(controller.allReports.length, 1);
    });

    test('the controller passes the location parts through to the repository', () async {
      final repository = FakeReportRepository();
      final controller = DashboardController(repository);

      await controller.addReport(
        title: 'Sony Headphones',
        type: ReportType.found,
        campus: 'BCI',
        area: 'Library',
        itemColor: 'Black',
        additionalDetails: 'Left on a table near the window',
        category: 'electronics',
      );

      final created = controller.allReports.single;
      expect(created.campus, 'BCI');
      expect(created.area, 'Library');
      expect(created.location, 'BCI · Library');
      expect(created.displayTitle, 'Black Sony Headphones');
      expect(created.icon, Icons.smartphone);
    });

    test('filters and search compose', () {
      final repository = FakeReportRepository([
        _item(id: '1', title: 'Lost Wallet', type: ReportType.lost, area: 'Downtown'),
        _item(id: '2', title: 'Found Phone', type: ReportType.found, area: 'Airport'),
        _item(id: '3', title: 'Lost Keys', type: ReportType.lost, area: 'Airport'),
      ]);
      final controller = DashboardController(repository);

      expect(controller.filteredReports.length, 3);

      controller.setFilter(ReportType.lost);
      expect(controller.filteredReports.length, 2);

      controller.setSearchQuery('airport');
      expect(controller.filteredReports.length, 1);
      expect(controller.filteredReports.first.id, '3');
    });
  });

  group('Filter strategies (OCP)', () {
    final items = [
      _item(id: '1', title: 'Lost Wallet', type: ReportType.lost, area: 'Downtown'),
      _item(id: '2', title: 'Found Phone', type: ReportType.found, area: 'Airport'),
    ];

    test('each strategy returns only its own type', () {
      expect(AllReportsFilterStrategy().filter(items, '').length, 2);
      expect(LostReportsFilterStrategy().filter(items, '').single.id, '1');
      expect(FoundReportsFilterStrategy().filter(items, '').single.id, '2');
    });

    test('search matches title and area, case-insensitively', () {
      expect(AllReportsFilterStrategy().filter(items, 'WALLET').single.id, '1');
      expect(AllReportsFilterStrategy().filter(items, 'airport').single.id, '2');
      expect(AllReportsFilterStrategy().filter(items, 'nothing'), isEmpty);
    });

    test('search also matches the colour and the details line', () {
      final coloured = [
        ReportItem(
          id: '9',
          title: 'Backpack',
          itemColor: 'Blue',
          campus: 'BCI',
          area: 'Canteen',
          additionalDetails: 'Hanging on the third chair',
          type: ReportType.lost,
        ),
      ];
      expect(AllReportsFilterStrategy().filter(coloured, 'blue').single.id, '9');
      expect(AllReportsFilterStrategy().filter(coloured, 'third chair').single.id, '9');
    });
  });

  group('Widgets', () {
    testWidgets('the list screen shows an empty state when there is nothing to show',
        (tester) async {
      final repository = FakeReportRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ListenableProvider<IReportRepository>.value(value: repository),
            ChangeNotifierProvider(create: (_) => DashboardController(repository)),
          ],
          child: const MaterialApp(home: ReportListScreen(reportType: ReportType.lost)),
        ),
      );

      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });

    testWidgets('the segmented control reports the option that was tapped', (tester) async {
      var selected = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CustomSegmentedControl<bool>(
                options: const [
                  SegmentedOption(value: true, label: 'Sign In'),
                  SegmentedOption(value: false, label: 'Sign Up'),
                ],
                selectedValue: selected,
                onValueChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      expect(selected, isFalse);
    });

    testWidgets('the section header renders its title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SectionHeader(title: 'Recent Reports'))),
      );
      expect(find.text('Recent Reports'), findsOneWidget);
    });
  });
}

/// AuthController.submitAuth only touches the BuildContext after a *successful* call, so the
/// validation and failure paths can be exercised with a context that is never used.
class _DummyContext extends BuildContext {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
