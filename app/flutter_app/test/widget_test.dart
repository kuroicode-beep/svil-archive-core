// widget_test.dart — SAC 앱 smoke test

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sac_app/application/sac_container.dart';
import 'package:sac_app/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('SAC welcome screen smoke test', (WidgetTester tester) async {
    final container = await SacContainer.create();
    await tester.pumpWidget(SacApp(container: container));
    expect(find.text('SAC — SVIL Archive Core'), findsOneWidget);
    expect(find.text('새 Workspace 만들기 (기본 경로)'), findsOneWidget);
  });
}
