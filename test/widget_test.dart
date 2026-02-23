import 'package:flutter_test/flutter_test.dart';

import 'package:members/main.dart';

void main() {
  testWidgets('renders admin login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HooliganAdminApp());

    expect(find.text('Weather Hooligan Members Admin'), findsOneWidget);
  });
}
