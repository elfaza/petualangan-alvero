import 'package:flutter_test/flutter_test.dart';
import 'package:petualangan_alvero/game/learning_mission.dart';

void main() {
  group('learning mission catalog', () {
    test('contains five themed groups with five playable levels each', () {
      expect(LearningMission.catalog, hasLength(25));
      expect(LearningMission.catalog.map((mission) => mission.type), [
        ...List.filled(5, LearningActivityType.findLetter),
        ...List.filled(5, LearningActivityType.identifyColor),
        ...List.filled(5, LearningActivityType.continuePattern),
        ...List.filled(5, LearningActivityType.countObjects),
        ...List.filled(5, LearningActivityType.addObjects),
      ]);
    });

    test('each level has three progressively varied questions', () {
      for (final mission in LearningMission.catalog) {
        expect(mission.questions, hasLength(3), reason: mission.id);
        expect(
          mission.questions
              .map((question) => '${question.prompt}|${question.visual}')
              .toSet(),
          hasLength(3),
          reason: mission.id,
        );
      }
    });

    test(
      'letter levels vary uppercase, lowercase, and initial sound answers',
      () {
        final letterLevels = LearningMission.catalog.where(
          (mission) => mission.type == LearningActivityType.findLetter,
        );

        for (final mission in letterLevels) {
          expect(
            mission.questions.map((question) => question.correctAnswer).toSet(),
            hasLength(3),
            reason: mission.id,
          );
        }
      },
    );

    test('every question has one unambiguous correct choice', () {
      for (final mission in LearningMission.catalog) {
        expect(mission.skillId, isNotEmpty, reason: mission.id);
        for (final question in mission.questions) {
          expect(question.choices, isNotEmpty, reason: mission.id);
          expect(
            question.choices.toSet().length,
            question.choices.length,
            reason: mission.id,
          );
          expect(
            question.choices,
            contains(question.correctAnswer),
            reason: mission.id,
          );
          expect(question.prompt, isNotEmpty, reason: mission.id);
          expect(question.hint, isNotEmpty, reason: mission.id);
        }
      }
    });

    test('only concrete number missions ask children to collect objects', () {
      final collectionMissions = LearningMission.catalog
          .where((mission) => mission.collectionCount != null)
          .map((mission) => mission.type);

      expect(collectionMissions, hasLength(10));
      expect(collectionMissions.toSet(), {
        LearningActivityType.countObjects,
        LearningActivityType.addObjects,
      });
    });
  });
}
