import 'package:carryme/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand logo renders the app name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: BrandLogo()))));
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('primary button responds to taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PrimaryButton(label: 'Book', onPressed: () => taps++)),
    ));
    await tester.tap(find.text('Book'));
    expect(taps, 1);
  });
}
