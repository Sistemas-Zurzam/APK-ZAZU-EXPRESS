import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zazu_driver/main.dart';

void main() {
  testWidgets('La app inicia', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ZazuDriverApp()));
    expect(find.text('ZAZU Driver'), findsNothing);
  });
}
