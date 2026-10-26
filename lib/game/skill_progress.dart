/// Session-level progress state for one learning skill.
enum SkillStatus { notStarted, practicing, completedWithHelp, independent }

/// Records attempts separately for each skill instead of treating stars as mastery.
class SkillProgress {
  int attempts = 0;
  SkillStatus status = SkillStatus.notStarted;

  void recordAnswer({required bool correct, required bool hintUsed}) {
    attempts++;
    if (!correct) {
      status = SkillStatus.practicing;
      return;
    }
    status = hintUsed ? SkillStatus.completedWithHelp : SkillStatus.independent;
  }
}
