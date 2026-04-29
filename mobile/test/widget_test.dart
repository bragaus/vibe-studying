import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vibe_studying_mobile/app/app.dart';

void main() {
  testWidgets('app boots into splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VibeStudyingApp()));

    expect(find.text('VIBE_STUDYING'), findsOneWidget);
  });
}
