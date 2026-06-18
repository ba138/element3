import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:element3/main.dart';

void main() {
  testWidgets('App boots to the scan screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Element3App()));
    expect(find.text('Element 3'), findsWidgets);
    expect(find.text('Find your battery'), findsOneWidget);
  });
}
