// Renders Kraken's icon masters from the vector glyph in the UI kit.
// Run through tool/icons/make_icons.sh, not directly.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kraken/ui_kit/ui_kit.dart';
import 'package:material_ui/material_ui.dart';

const blue = Color(0xFF2348DE);
const white = Color(0xFFFFFFFF);

Future<void> render(WidgetTester t, String name, Widget child, {Size size = const Size(1024, 1024)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: KrakenTheme.light(),
      color: Colors.transparent,
      home: Material(
        type: MaterialType.transparency,
        child: Center(
          child: RepaintBoundary(key: const ValueKey('art'), child: child),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await expectLater(find.byKey(const ValueKey('art')), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(() async {
    final poppins = FontLoader('Poppins')
      ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Poppins-Bold.ttf').readAsBytesSync())));
    await poppins.load();
  });

  testWidgets('icon masters', (t) async {
    addTearDown(t.view.reset);
    const glyphIos = 1024 * KrakenGlyphGeometry.iconWidthRatio / KrakenGlyphGeometry.aspect;

    // iOS: full-bleed square, no transparency. iOS rounds the corners.
    await render(
      t,
      'ios_1024',
      Container(
        width: 1024,
        height: 1024,
        color: blue,
        alignment: Alignment.center,
        child: const KrakenGlyph(height: glyphIos, color: white),
      ),
    );

    // Android before 8.0: the rounded tile itself, on transparency.
    await render(t, 'android_legacy_1024', const KrakenMark(size: 1024, background: blue, foreground: white));

    // Android 8.0+ adaptive icon foreground: glyph on a 108dp canvas whose
    // visible area is the middle 72dp, so it is scaled by 72/108.
    const glyphAdaptive = glyphIos * 72 / 108;
    await render(
      t,
      'android_foreground_1024',
      const SizedBox(
        width: 1024,
        height: 1024,
        child: Center(
          child: KrakenGlyph(height: glyphAdaptive, color: white),
        ),
      ),
    );

    // A preview sheet to compare against the brand board.
    await render(
      t,
      'preview',
      size: const Size(960, 360),
      Container(
        width: 960,
        height: 360,
        color: const Color(0xFFF3F4F6),
        padding: const EdgeInsets.all(40),
        child: Row(
          children: [
            const KrakenMark(size: 220, background: blue, foreground: white),
            const SizedBox(width: 40),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KrakenLogo(fontSize: 56, glyphHeight: 48),
                const SizedBox(height: 32),
                Row(
                  children: [
                    for (final s in [88.0, 60.0, 40.0, 28.0]) ...[
                      KrakenMark(size: s, background: blue, foreground: white),
                      const SizedBox(width: 14),
                    ],
                    const SizedBox(width: 20),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: white,
                        border: Border.all(color: const Color(0xFFE4E6EB)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const KrakenGlyph(height: 27, color: Color(0xFF15171C)),
                    ),
                    const SizedBox(width: 14),
                    const KrakenMark(size: 60, background: Color(0xFF15171C), foreground: white),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  });
}
