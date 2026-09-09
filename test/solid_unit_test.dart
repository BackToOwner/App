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
import 'package:back_to_owner/viewmodels/auth_viewmodel.dart';
import 'package:back_to_owner/viewmodels/dashboard_viewmodel.dart';
import 'package:back_to_owner/widgets/custom_segmented_control.dart';
import 'package:back_to_owner/widgets/empty_state_widget.dart';
import 'package:back_to_owner/widgets/section_header.dart';

/// Stands in for the real service so the view-models can be tested without a server.
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
    required String location,
    String? description,
    String? category,
    double? reward,
    double? lat,
    double? lng,
    String? imagePath,
  }) async {
    final item = ReportItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      location: location,
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
  String location = 'Somewhere',
  bool isMine = false,
}) =>
    ReportItem(
      id: id,
      title: title,
      location: location,
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
      final vm = AuthViewModel(auth)
        ..emailController.text = FakeAuthService.validEmail
        ..passwordController.text = '';

      // Validation happens before the call, so the service is never asked.
      expect(await vm.submitAuth(_DummyContext()), isNull);
      expect(auth.signInCalls, 0);
      expect(vm.errorMessage, 'Please enter your password.');
    });

    test('a malformed email is caught locally', () async {
      final auth = FakeAuthService();
      final vm = AuthViewModel(auth)
        ..emailController.text = 'not-an-email'
        ..passwordController.text = 'password123';

      expect(await vm.submitAuth(_DummyContext()), isNull);
      expect(auth.signInCalls, 0);
      expect(vm.errorMessage, contains('valid email'));
    });

    test('a rejected sign-in surfaces the server message', () async {
      final auth = FakeAuthService();
      final vm = AuthViewModel(auth)
        ..emailController.text = FakeAuthService.validEmail
        ..passwordController.text = 'wrong-password';

      expect(await vm.submitAuth(_DummyContext()), isNull);
      expect(auth.signInCalls, 1);
      expect(vm.errorMessage, 'Invalid email or password');
    });

    test('sign-up enforces the 8 character minimum the server requires', () async {
      final auth = FakeAuthService();
      final vm = AuthViewModel(auth)
        ..setAuthMode(false)
        ..emailController.text = 'new@example.com'
        ..passwordController.text = 'short';

      expect(await vm.submitAuth(_DummyContext()), isNull);
      expect(vm.errorMessage, contains('at least 8 characters'));
    });
  });

  group('ReportItem parsing', () {
    test('builds from an API payload', () {
      final item = ReportItem.fromJson({
        'id': 'LST-1',
        'title': 'Black Leather Wallet',
        'type': 'lost',
        'status': 'open',
        'location': 'Colombo',
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
    });

    test('survives a payload with missing optional fields', () {
      final item = ReportItem.fromJson({'id': 'X', 'type': 'found'});
      expect(item.title, '');
      expect(item.type, ReportType.found);
      expect(item.emojiIcon, '📦');
      expect(item.reward, isNull);
      expect(item.images, isEmpty);
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
            location: 'l',
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
      ReportItem withStatus(String? s) =>
          ReportItem(id: 'X', title: 't', location: 'l', type: ReportType.lost, status: s);

      expect(withStatus('matched').statusLabel, 'MATCHED');
      expect(withStatus('returned').statusLabel, 'RETURNED');
      expect(withStatus('open').statusLabel, isNull);
    });
  });

  group('Repository and view-model (ISP, DIP, LSP)', () {
    test('reads, writes and separates the caller\'s own reports', () async {
      final repository = FakeReportRepository();
      expect(repository.getAllReports(), isEmpty);

      await repository.addReport(title: 'Lost Wallet', type: ReportType.lost, location: 'Downtown');
      await repository.addReport(title: 'Found Keys', type: ReportType.found, location: 'Park');
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

    test('the view-model notifies listeners when the repository changes', () async {
      final repository = FakeReportRepository();
      final vm = DashboardViewModel(repository);

      var notified = 0;
      vm.addListener(() => notified++);

      await vm.addReport(title: 'New', type: ReportType.lost, location: 'Here');
      expect(notified, greaterThan(0));
      expect(vm.allReports.length, 1);
    });

    test('filters and search compose', () {
      final repository = FakeReportRepository([
        _item(id: '1', title: 'Lost Wallet', type: ReportType.lost, location: 'Downtown'),
        _item(id: '2', title: 'Found Phone', type: ReportType.found, location: 'Airport'),
        _item(id: '3', title: 'Lost Keys', type: ReportType.lost, location: 'Airport'),
      ]);
      final vm = DashboardViewModel(repository);

      expect(vm.filteredReports.length, 3);

      vm.setFilter(ReportType.lost);
      expect(vm.filteredReports.length, 2);

      vm.setSearchQuery('airport');
      expect(vm.filteredReports.length, 1);
      expect(vm.filteredReports.first.id, '3');
    });
  });

  group('Filter strategies (OCP)', () {
    final items = [
      _item(id: '1', title: 'Lost Wallet', type: ReportType.lost, location: 'Downtown'),
      _item(id: '2', title: 'Found Phone', type: ReportType.found, location: 'Airport'),
    ];

    test('each strategy returns only its own type', () {
      expect(AllReportsFilterStrategy().filter(items, '').length, 2);
      expect(LostReportsFilterStrategy().filter(items, '').single.id, '1');
      expect(FoundReportsFilterStrategy().filter(items, '').single.id, '2');
    });

    test('search matches title and location, case-insensitively', () {
      expect(AllReportsFilterStrategy().filter(items, 'WALLET').single.id, '1');
      expect(AllReportsFilterStrategy().filter(items, 'airport').single.id, '2');
      expect(AllReportsFilterStrategy().filter(items, 'nothing'), isEmpty);
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
            ChangeNotifierProvider(create: (_) => DashboardViewModel(repository)),
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

/// AuthViewModel.submitAuth only touches the BuildContext after a *successful* call, so the
/// validation and failure paths can be exercised with a context that is never used.
class _DummyContext extends BuildContext {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
