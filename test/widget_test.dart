import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petualangan_alvero/main.dart';

void main() {
  testWidgets('level membuka cerita misi layar penuh sebelum mulai berhitung', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    await tester.tap(find.byKey(const ValueKey('map-level-0')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('mission-intro')), findsOneWidget);
    expect(find.byKey(const ValueKey('mission-scene')), findsOneWidget);
    expect(find.byKey(const ValueKey('mission-prop')), findsOneWidget);
    expect(
      find.text('Alvero mau piknik, tapi bekalnya belum lengkap. Bantu aku, ya!'),
      findsOneWidget,
    );
    expect(find.text('Siapkan 5 apel untuk bekal!'), findsOneWidget);
    expect(find.text('2 + 3 = ?'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-mission')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2 + 3 = ?'), findsOneWidget);
  });

  testWidgets('nama game Alvero muncul di splash screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));

    expect(find.text('PETUALANGAN ALVERO'), findsOneWidget);
  });

  testWidgets('soal penjumlahan dan pilihan jawaban ditampilkan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    expect(find.byKey(const ValueKey('splash-screen')), findsOneWidget);
    await _startFromSplash(tester);
    expect(find.text('PETA PETUALANGAN'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-level-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-level-4')), findsOneWidget);
    expect(find.text('2 + 3 = ?'), findsNothing);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('map-level-1'))).onTap,
      isNull,
    );
    await _enterLevel(tester, 0);
    expect(find.text('2 + 3 = ?'), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-6')), findsOneWidget);
    expect(find.text('Bekal piknik'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('level-pemula')));
    await tester.pump();
    expect(find.text('1 + 2 = ?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('level-menengah')));
    await tester.pump();
    expect(find.text('2 + 3 = ?'), findsOneWidget);
  });

  testWidgets('jawaban salah bisa dicoba lagi, jawaban benar membuka misi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    await _enterLevel(tester, 0);
    await tester.tap(find.byKey(const ValueKey('answer-4')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wrong-answer-dialog')), findsOneWidget);
    expect(find.text('Belum tepat. Coba hitung lagi, ya!'), findsNothing);
    await tester.tap(find.text('COBA LAGI'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('answer-5')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('answer-5')));
    await tester.pump();
    expect(find.text('Benar! Masukkan 5 apel ke bekal.'), findsOneWidget);
    expect(find.byKey(const ValueKey('collection-item-0')), findsOneWidget);
  });

  testWidgets('tombol suara mengaktifkan dan mematikan musik', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    expect(find.byTooltip('Nyalakan suara'), findsOneWidget);

    await tester.tap(find.byTooltip('Nyalakan suara'));
    await tester.pump();
    expect(find.byTooltip('Matikan suara'), findsOneWidget);

    await tester.tap(find.byTooltip('Matikan suara'));
    await tester.pump();
    expect(find.byTooltip('Nyalakan suara'), findsOneWidget);
  });

  testWidgets('memetik apel menyelesaikan ronde dan membuka tombol lanjut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    expect(find.text('0 / 5 pos'), findsOneWidget);
    expect(find.text('Kebun'), findsOneWidget);
    await _enterLevel(tester, 0);
    await tester.tap(find.byKey(const ValueKey('answer-5')));
    await tester.pump();

    for (var apple = 0; apple < 5; apple++) {
      await tester.tap(find.byKey(ValueKey('collection-item-$apple')));
      await tester.pump(const Duration(milliseconds: 450));
    }

    expect(find.byKey(const ValueKey('mission-complete')), findsOneWidget);
    expect(
      find.text('Bekal piknik siap! Teman-teman Alvero siap berangkat!'),
      findsOneWidget,
    );
    expect(find.text('LANJUT KE PETA'), findsOneWidget);
  });

  testWidgets('misi berubah saat lanjut ke ronde berikutnya', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    await _enterLevel(tester, 0);
    final firstCorrectSlot = _answerSlot(tester, 5, [4, 5, 6]);
    await tester.tap(find.byKey(const ValueKey('answer-5')));
    await tester.pump();
    for (var apple = 0; apple < 5; apple++) {
      await tester.tap(find.byKey(ValueKey('collection-item-$apple')));
      await tester.pump(const Duration(milliseconds: 450));
    }
    expect(find.byKey(const ValueKey('mission-complete')), findsOneWidget);
    await tester.tap(find.text('LANJUT KE PETA'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 / 5 pos'), findsOneWidget);
    expect(
      find.text('Tujuan berikutnya: Padang kelinci · 2 / 5'),
      findsOneWidget,
    );
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('map-level-1'))).onTap,
      isNotNull,
    );
    await _enterLevel(tester, 1);
    expect(find.text('Sarapan kelinci'), findsOneWidget);
    expect(find.text('4 + 2 = ?'), findsOneWidget);
    expect(_answerSlot(tester, 6, [5, 6, 7]), isNot(firstCorrectSlot));
    await tester.tap(find.byKey(const ValueKey('answer-6')));
    await tester.pump();
    expect(
      find.text('Benar! Berikan 6 wortel kepada kelinci.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('collection-item-0')), findsOneWidget);
    expect(find.text('BERI MAKAN KELINCI!'), findsOneWidget);
  });
}

Future<void> _startFromSplash(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('start-adventure')));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _enterLevel(WidgetTester tester, int level) async {
  await tester.tap(find.byKey(ValueKey('map-level-$level')));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const ValueKey('start-mission')));
  await tester.pump(const Duration(milliseconds: 500));
}

int _answerSlot(WidgetTester tester, int correct, List<int> answers) {
  final orderedAnswers = [...answers]
    ..sort(
      (first, second) => tester
          .getCenter(find.byKey(ValueKey('answer-$first')))
          .dx
          .compareTo(
            tester.getCenter(find.byKey(ValueKey('answer-$second'))).dx,
          ),
    );
  return orderedAnswers.indexOf(correct);
}
