import 'package:flutter_test/flutter_test.dart';
import 'package:petualangan_alvero/game/skill_progress.dart';

void main() {
  test('a correct first attempt records independent progress', () {
    final progress = SkillProgress();

    progress.recordAnswer(correct: true, hintUsed: false);

    expect(progress.attempts, 1);
    expect(progress.status, SkillStatus.independent);
  });

  test('a correct answer after a hint records supported progress', () {
    final progress = SkillProgress();
    progress.recordAnswer(correct: false, hintUsed: false);

    progress.recordAnswer(correct: true, hintUsed: true);

    expect(progress.attempts, 2);
    expect(progress.status, SkillStatus.completedWithHelp);
  });

  test('an incorrect attempt keeps a skill in practice', () {
    final progress = SkillProgress();

    progress.recordAnswer(correct: false, hintUsed: false);

    expect(progress.status, SkillStatus.practicing);
  });
}
