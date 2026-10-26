import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petualangan_alvero/game/learning_mission.dart';
import 'package:petualangan_alvero/main.dart';

void main() {
  testWidgets('level membuka cerita misi huruf sebelum mulai bermain', (
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
      find.text('Alvero mau memberi label pada bekal. Yuk, temukan huruf A!'),
      findsOneWidget,
    );
    expect(find.text('Bantu Alvero menemukan huruf A.'), findsOneWidget);
    expect(find.text('Mana huruf A?'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('start-mission')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mana huruf A?'), findsOneWidget);
  });

  testWidgets('nama game Alvero muncul di splash screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));

    expect(find.text('PETUALANGAN ALVERO'), findsOneWidget);
  });

  testWidgets('peta membuka jalur dari pengenalan huruf ke berhitung', (
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
    expect(find.byKey(const ValueKey('map-level-24')), findsOneWidget);
    expect(
      find.text('Lima tempat seru dan 25 level menantimu'),
      findsOneWidget,
    );
    expect(find.text('Mana huruf A?'), findsNothing);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('map-level-1'))).onTap,
      isNull,
    );
    await _enterLevel(tester, 0);
    expect(find.text('Mana huruf A?'), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-A')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-M')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-O')), findsOneWidget);
    expect(find.text('Huruf A'), findsOneWidget);
    expect(find.text('Pai Apel'), findsNothing);

    expect(find.text('PEMULA'), findsNothing);
    expect(find.text('MENENGAH'), findsNothing);
  });

  testWidgets('progress soal terisi bertahap di dalam satu level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    await _enterLevel(tester, 0);

    LinearProgressIndicator progress() =>
        tester.widget(find.byType(LinearProgressIndicator));

    expect(progress().value, closeTo(1 / 3, 0.001));
    await tester.tap(find.byKey(const ValueKey('answer-A')));
    await tester.pump();
    await tester.tap(find.text('LANJUT SOAL'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(progress().value, closeTo(2 / 3, 0.001));
  });

  testWidgets('kartu level peta muat tanpa overflow di layar ponsel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);

    expect(find.byKey(const ValueKey('map-level-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('label aksi misi tidak menimpa karakter pada layar ponsel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    await _enterLevel(tester, 0);

    final label = tester.getRect(find.byKey(const ValueKey('mission-action')));
    final character = tester.getRect(
      find.byKey(const ValueKey('mission-character')),
    );
    expect(label.overlaps(character), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'jawaban salah memberi petunjuk dan jawaban benar menyelesaikan misi',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
      await _startFromSplash(tester);
      await _enterLevel(tester, 0);
      await tester.tap(find.byKey(const ValueKey('answer-M')));
      await tester.pump();
      expect(find.byKey(const ValueKey('wrong-answer-dialog')), findsOneWidget);
      expect(
        find.text('Cari huruf yang bentuknya seperti A di kartu bekal.'),
        findsOneWidget,
      );
      await tester.tap(find.text('COBA LAGI'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('answer-A')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('answer-A')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('question-correct-feedback')),
        findsOneWidget,
      );
      await tester.tap(find.text('LANJUT SOAL'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('answer-A')));
      await tester.pump();
      await tester.tap(find.text('LANJUT SOAL'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('answer-A')));
      await tester.pump();
      expect(find.byKey(const ValueKey('mission-complete')), findsOneWidget);
      expect(
        find.text('Kamu berhasil dengan petunjuk Alvero!'),
        findsOneWidget,
      );
    },
  );

  testWidgets('suara aktif secara default dan tombol bisa mematikannya', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    expect(find.byTooltip('Matikan suara'), findsOneWidget);

    await tester.tap(find.byTooltip('Matikan suara'));
    await tester.pump();
    expect(find.byTooltip('Nyalakan suara'), findsOneWidget);

    await tester.tap(find.byTooltip('Nyalakan suara'));
    await tester.pump();
    expect(find.byTooltip('Matikan suara'), findsOneWidget);
  });

  testWidgets(
    'menghitung wortel lalu memberi makan kelinci menyelesaikan misi',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
      await _startFromSplash(tester);
      expect(find.text('Tujuan: Kebun huruf · 1 / 25'), findsOneWidget);
      expect(find.text('Kebun huruf'), findsOneWidget);
      for (var level = 0; level < 15; level++) {
        await _completeChoiceMission(tester, level);
      }
      await _enterLevel(tester, 15);
      expect(find.text('Ada berapa wortel? Hitung satu-satu!'), findsOneWidget);
      await _answerCurrentQuestion(tester, '1');
      await _answerCurrentQuestion(tester, '2');
      await tester.tap(find.byKey(const ValueKey('answer-3')));
      await tester.pump();

      for (var carrot = 0; carrot < 3; carrot++) {
        await tester.tap(find.byKey(ValueKey('collection-item-$carrot')));
        await tester.pump(const Duration(milliseconds: 450));
      }

      expect(find.byKey(const ValueKey('mission-complete')), findsOneWidget);
      expect(
        find.text('Kelinci-kelinci sudah kenyang dan senang!'),
        findsOneWidget,
      );
      expect(find.text('LANJUT KE PETA'), findsOneWidget);
    },
  );

  testWidgets('lima level huruf membuka tema warna', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PetualanganAlveroApp(audioEnabled: false));
    await _startFromSplash(tester);
    for (var level = 0; level < 5; level++) {
      await _completeChoiceMission(tester, level);
    }
    expect(find.text('Tujuan: Taman warna · 6 / 25'), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('map-level-5'))).onTap,
      isNotNull,
    );
    await _enterLevel(tester, 5);
    expect(find.text('Warna Kuning'), findsOneWidget);
    expect(find.text('Pilih bunga yang berwarna kuning!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('answer-🌼 Kuning')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('question-correct-feedback')),
      findsOneWidget,
    );
  });
}

Future<void> _completeChoiceMission(WidgetTester tester, int level) async {
  await _enterLevel(tester, level);
  final mission = LearningMission.catalog[level];
  for (var question = 0; question < mission.questions.length; question++) {
    final answer = mission.questions[question].correctAnswer;
    await tester.tap(find.byKey(ValueKey('answer-$answer')));
    await tester.pump();
    if (question < mission.questions.length - 1) {
      await tester.tap(find.text('LANJUT SOAL'));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }
  expect(find.byKey(const ValueKey('mission-complete')), findsOneWidget);
  await tester.tap(find.text('LANJUT KE PETA'));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _answerCurrentQuestion(WidgetTester tester, String answer) async {
  await tester.tap(find.byKey(ValueKey('answer-$answer')));
  await tester.pump();
  await tester.tap(find.text('LANJUT SOAL'));
  await tester.pump(const Duration(milliseconds: 400));
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
