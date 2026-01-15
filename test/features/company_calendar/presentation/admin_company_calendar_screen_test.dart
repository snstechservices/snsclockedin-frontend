import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sns_clocked_in/features/company_calendar/application/company_calendar_store.dart';
import 'package:sns_clocked_in/features/company_calendar/data/company_calendar_repository.dart';
import 'package:sns_clocked_in/features/company_calendar/domain/calendar_day.dart';
import 'package:sns_clocked_in/features/company_calendar/presentation/admin_company_calendar_screen.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('AdminCompanyCalendarScreen', () {
    late CompanyCalendarStore store;
    late MockCompanyCalendarRepository repository;

    setUp(() {
      repository = MockCompanyCalendarRepository();
      store = CompanyCalendarStore(repository: repository);
    });

    tearDown(() {
      store.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<CompanyCalendarStore>.value(
            value: store,
            child: const AdminCompanyCalendarScreen(),
          ),
        ),
      );
    }

    testWidgets('displays quick stats section at top', (tester) async {
      // Load current month data
      final now = DateTime.now();
      await store.loadCalendarDays(year: now.year, month: now.month);
      await store.loadConfig();
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show quick stats section with title
      expect(find.textContaining('Calendar Summary'), findsOneWidget);
      
      // Should show stat cards
      expect(find.textContaining('Working Days'), findsOneWidget);
      expect(find.textContaining('Holidays'), findsOneWidget);
      expect(find.textContaining('Non-Working'), findsOneWidget);
    });

    testWidgets('displays bottom navigation tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show all 4 tabs
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Working Days'), findsOneWidget);
      expect(find.text('Holidays'), findsOneWidget);
      expect(find.text('Non-Working'), findsOneWidget);
    });

    testWidgets('can switch between tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on Holidays tab
      await tester.tap(find.text('Holidays'));
      await tester.pumpAndSettle();

      // Should show holidays content
      expect(find.textContaining('Holidays Management'), findsOneWidget);

      // Tap on Working Days tab
      await tester.tap(find.text('Working Days'));
      await tester.pumpAndSettle();

      // Should show working days content
      expect(find.textContaining('Working Days Configuration'), findsOneWidget);
    });

    testWidgets('quick stats calculate from current month', (tester) async {
      final now = DateTime.now();
      await store.loadCalendarDays(year: now.year, month: now.month);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final currentMonthDays = store.getCalendarDays(now.year, now.month);
      
      // Stats should reflect current month data
      expect(currentMonthDays.length, greaterThan(0));
    });
  });
}

// Mock repository for testing
class MockCompanyCalendarRepository implements CompanyCalendarRepository {
  @override
  Future<CompanyCalendarConfig> getCalendarConfig() async {
    return const CompanyCalendarConfig(
      workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    );
  }

  @override
  Future<List<CalendarDay>> getCalendarDays({
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    // Return mock calendar days for the month
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final days = <CalendarDay>[];
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final weekday = date.weekday;
      
      DayType type;
      if (weekday == 6 || weekday == 7) {
        type = DayType.weekend;
      } else {
        type = DayType.working;
      }
      
      days.add(CalendarDay(date: date, type: type));
    }
    
    return days;
  }

  @override
  Future<CalendarDay?> getDayDetails(DateTime date) async {
    final days = await getCalendarDays(year: date.year, month: date.month);
    return days.firstWhere(
      (d) => d.date.year == date.year && d.date.month == date.month && d.date.day == date.day,
      orElse: () => CalendarDay(date: date, type: DayType.working),
    );
  }
}
