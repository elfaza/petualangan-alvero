import 'dart:math' as math;

/// The kind of early-learning activity used by a mission.
enum LearningActivityType {
  findLetter,
  identifyColor,
  continuePattern,
  countObjects,
  addObjects,
}

/// One short question in a level.
class LearningQuestion {
  const LearningQuestion({
    required this.prompt,
    required this.hint,
    required this.visual,
    required this.choices,
    required this.correctAnswer,
    required this.feedback,
  });

  final String prompt;
  final String hint;
  final String visual;
  final List<String> choices;
  final String correctAnswer;
  final String feedback;
}

/// Content and learning goal for one playable Alvero level.
class LearningMission {
  const LearningMission({
    required this.id,
    required this.themeIndex,
    required this.skillId,
    required this.type,
    required this.title,
    required this.description,
    required this.story,
    required this.actionLabel,
    required this.goalLine,
    required this.questions,
    required this.result,
    required this.collectionCount,
    required this.collectionLabel,
    required this.collectionPrompt,
    required this.collectionButtonLabel,
    required this.destinationLabel,
    required this.collectionEmoji,
  });

  final String id;
  final int themeIndex;
  final String skillId;
  final LearningActivityType type;
  final String title;
  final String description;
  final String story;
  final String actionLabel;
  final String goalLine;
  final List<LearningQuestion> questions;
  final String result;
  final int? collectionCount;
  final String collectionLabel;
  final String collectionPrompt;
  final String collectionButtonLabel;
  final String destinationLabel;
  final String collectionEmoji;

  bool get usesObjectCollection => collectionCount != null;

  // These accessors keep the first question convenient for older callers.
  String get prompt => questions.first.prompt;
  String get hint => questions.first.hint;
  String get questionVisual => questions.first.visual;
  List<String> get choices => questions.first.choices;
  String get correctAnswer => questions.first.correctAnswer;
  String get correctFeedback => questions.first.feedback;

  static final List<LearningMission> catalog = _buildCatalog();

  static List<LearningMission> _buildCatalog() => [
    ..._letterLevels(),
    ..._colorLevels(),
    ..._patternLevels(),
    ..._countingLevels(),
    ..._additionLevels(),
  ];

  static List<LearningMission> _letterLevels() {
    const letters = ['A', 'B', 'C', 'D', 'E'];
    const distractors = [
      ['M', 'O', 'R', 'S'],
      ['D', 'P', 'R', 'H'],
      ['G', 'O', 'Q', 'S'],
      ['B', 'P', 'T', 'F'],
      ['F', 'P', 'R', 'G'],
    ];
    return List.generate(5, (level) {
      final letter = letters[level];
      final questions = List.generate(3, (question) {
        final other = distractors[level];
        final lowercaseLetter = letter.toLowerCase();
        final wordChoices = switch (letter) {
          'A' => ['apel', 'bola', 'rumah'],
          'B' => ['bola', 'apel', 'rumah'],
          'C' => ['cicak', 'bola', 'apel'],
          'D' => ['dadu', 'bola', 'apel'],
          _ => ['es', 'apel', 'bola'],
        };
        final choices = switch (question) {
          0 => [letter, other[0], other[1]],
          1 => [
            lowercaseLetter,
            other[1].toLowerCase(),
            other[2].toLowerCase(),
          ],
          _ => wordChoices,
        };
        final answer = switch (question) {
          0 => letter,
          1 => lowercaseLetter,
          _ => wordChoices.first,
        };
        return LearningQuestion(
          prompt: switch (question) {
            0 => 'Mana huruf $letter?',
            1 => 'Mana huruf kecil $lowercaseLetter?',
            _ => 'Kata mana yang diawali huruf $letter?',
          },
          hint: switch (question) {
            0 => 'Cari bentuk huruf besar $letter di antara pilihan.',
            1 => 'Cari bentuk huruf kecil $lowercaseLetter di antara pilihan.',
            _ => 'Ucapkan kata pelan-pelan dan dengarkan bunyi awalnya.',
          },
          visual: '',
          choices: choices,
          correctAnswer: answer,
          feedback: switch (question) {
            0 => 'Betul! Itu huruf besar $letter.',
            1 => 'Betul! Itu huruf kecil $lowercaseLetter.',
            _ => 'Betul! $answer diawali huruf $letter.',
          },
        );
      });
      return _mission(
        level: level,
        skillId: 'letter-recognition',
        type: LearningActivityType.findLetter,
        title: 'Huruf $letter',
        description: 'Kenali huruf $letter di sekitar kita.',
        story: 'Alvero menemukan kartu huruf. Yuk, bantu cari huruf $letter!',
        actionLabel: 'Mencari huruf $letter',
        goalLine: 'Bantu Alvero menemukan huruf $letter.',
        questions: questions,
        result: 'Huruf $letter ditemukan! Alvero makin dekat ke taman warna.',
      );
    });
  }

  static List<LearningMission> _colorLevels() {
    const colors = [
      (name: 'kuning', emoji: '🌼', object: 'bunga'),
      (name: 'merah', emoji: '🍎', object: 'apel'),
      (name: 'biru', emoji: '🦋', object: 'kupu-kupu'),
      (name: 'hijau', emoji: '🍃', object: 'daun'),
      (name: 'ungu', emoji: '🌷', object: 'bunga'),
    ];
    const options = ['🌼 Kuning', '🍎 Merah', '🦋 Biru', '🍃 Hijau', '🌷 Ungu'];
    return List.generate(5, (level) {
      final color = colors[level];
      final answer = options[level];
      final questions = List.generate(3, (question) {
        final object = switch (question) {
          0 => color.object,
          1 => 'benda ${color.object}',
          _ => 'gambar ${color.object}',
        };
        final choices = [
          answer,
          options[(level + 1 + question) % options.length],
          options[(level + 2 + question) % options.length],
        ];
        return LearningQuestion(
          prompt: 'Pilih $object yang berwarna ${color.name}!',
          hint: 'Lihat warna ikon dan cari yang cocok dengan ${color.name}.',
          visual: '${color.emoji}   🌻   🌸',
          choices: choices,
          correctAnswer: answer,
          feedback: 'Iya, itu berwarna ${color.name}!',
        );
      });
      return _mission(
        level: level,
        skillId: 'color-recognition',
        type: LearningActivityType.identifyColor,
        title: 'Warna ${color.name[0].toUpperCase()}${color.name.substring(1)}',
        description: 'Amati warna, lalu pilih gambar yang cocok.',
        story: 'Taman Alvero butuh warna ${color.name}. Yuk, bantu memilih!',
        actionLabel: 'Mencari warna ${color.name}',
        goalLine: 'Pilih gambar dengan warna ${color.name}.',
        questions: questions,
        result: 'Warna ${color.name} ditemukan. Taman Alvero makin indah!',
      );
    });
  }

  static List<LearningMission> _patternLevels() {
    const names = [
      'Pola berulang',
      'Pola dua-dua',
      'Pola selang-seling',
      'Pola tiga gambar',
      'Urutan angka',
    ];
    const variants = <List<(String, String, String, String)>>[
      [
        ('🍎  🥕  🍎', '🥕 Wortel', '🍐 Pir', '🍎 Apel'),
        ('🍓  🍇  🍓', '🍇 Anggur', '🍐 Pir', '🍎 Apel'),
        ('🌼  🌷  🌼', '🌷 Bunga', '🍃 Daun', '🌼 Bunga kuning'),
      ],
      [
        ('🍓  🍓  🍐  🍓  🍓', '🍐 Pir', '🍎 Apel', '🍓 Stroberi'),
        ('🍎  🍎  🍇  🍎  🍎', '🍇 Anggur', '🍐 Pir', '🍎 Apel'),
        ('🌼  🌼  🌷  🌼  🌼', '🌷 Bunga', '🍃 Daun', '🌼 Bunga kuning'),
      ],
      [
        ('🌼  🌷  🌷  🌼  🌷', '🌷 Bunga', '🍎 Apel', '🌼 Bunga kuning'),
        ('🍎  🍐  🍐  🍎  🍐', '🍐 Pir', '🍇 Anggur', '🍎 Apel'),
        ('🍓  🍇  🍇  🍓  🍇', '🍇 Anggur', '🍐 Pir', '🍓 Stroberi'),
      ],
      [
        ('🍎  🍐  🍇  🍎  🍐', '🍇 Anggur', '🍎 Apel', '🍐 Pir'),
        ('🌼  🌷  🍃  🌼  🌷', '🍃 Daun', '🌼 Bunga kuning', '🌷 Bunga'),
        ('🍓  🍎  🍐  🍓  🍎', '🍐 Pir', '🍓 Stroberi', '🍎 Apel'),
      ],
      [
        ('1  ·  2  ·  3  ·  1  ·  2', '3', '4', '1'),
        ('2  ·  3  ·  4  ·  2  ·  3', '4', '5', '2'),
        ('3  ·  4  ·  5  ·  3  ·  4', '5', '6', '3'),
      ],
    ];
    return List.generate(5, (level) {
      final questions = List.generate(3, (question) {
        final pattern = variants[level][question];
        return LearningQuestion(
          prompt: '${pattern.$1}  ?',
          hint: 'Perhatikan urutan gambar. Bagian mana yang berulang?',
          visual: '',
          choices: [pattern.$2, pattern.$3, pattern.$4],
          correctAnswer: pattern.$2,
          feedback: 'Benar! Kamu menemukan pola yang berulang.',
        );
      });
      return _mission(
        level: level,
        skillId: 'pattern-sequence',
        type: LearningActivityType.continuePattern,
        title: names[level],
        description: 'Amati urutan, lalu pilih gambar berikutnya.',
        story: 'Jalur piknik Alvero punya pola. Bantu lengkapi urutannya!',
        actionLabel: 'Melanjutkan pola',
        goalLine: 'Cari benda yang melanjutkan pola.',
        questions: questions,
        result: 'Polanya lengkap! Alvero bisa lanjut ke padang kelinci.',
      );
    });
  }

  static List<LearningMission> _countingLevels() {
    return List.generate(5, (level) {
      final firstCount = level + 1;
      final questions = List.generate(3, (question) {
        final count = firstCount + question;
        final visual = List.filled(count, '🥕').join('  ');
        final answer = '$count';
        return LearningQuestion(
          prompt: 'Ada berapa wortel? Hitung satu-satu!',
          hint: 'Sentuh setiap wortel satu kali sambil menghitung.',
          visual: visual,
          choices: ['${math.max(0, count - 1)}', answer, '${count + 1}'],
          correctAnswer: answer,
          feedback: 'Betul! Ada $count wortel.',
        );
      });
      final maxCount = firstCount + 2;
      return _mission(
        level: level,
        skillId: 'one-to-one-counting',
        type: LearningActivityType.countObjects,
        title: 'Hitung sampai $maxCount',
        description: 'Hitung setiap benda satu kali dengan teliti.',
        story: 'Teman kelinci lapar. Hitung wortelnya dan bantu memberi makan!',
        actionLabel: 'Menghitung wortel',
        goalLine: 'Hitung wortel untuk kelinci.',
        questions: questions,
        result: 'Kelinci-kelinci sudah kenyang dan senang!',
        collectionCount: math.min(level + 3, 7),
        collectionLabel: 'wortel',
        collectionPrompt: 'Berikan wortel',
        collectionButtonLabel: 'BERI MAKAN KELINCI!',
        destinationLabel: 'TEMAN KELINCI',
        collectionEmoji: '🥕',
      );
    });
  }

  static List<LearningMission> _additionLevels() {
    const sums = [
      [(1, 1), (1, 2), (2, 2)],
      [(2, 3), (3, 3), (4, 2)],
      [(3, 4), (2, 6), (5, 4)],
      [(7, 4), (8, 5), (6, 7)],
      [(9, 6), (8, 10), (12, 7)],
    ];
    return List.generate(5, (level) {
      final questions = List.generate(3, (question) {
        final (left, right) = sums[level][question];
        final sum = left + right;
        final answer = '$sum';
        final visual =
            '${List.filled(left, '🍎').join(' ')}  +  '
            '${List.filled(right, '🍎').join(' ')}';
        return LearningQuestion(
          prompt: '$left + $right = ?',
          hint: 'Hitung apel di kelompok pertama, lalu lanjutkan ke kelompok kedua.',
          visual: visual,
          choices: ['${sum - 1}', answer, '${sum + 1}'],
          correctAnswer: answer,
          feedback: 'Benar! $left ditambah $right jadi $sum.',
        );
      });
      final limit = const [5, 10, 10, 15, 20][level];
      return _mission(
        level: level,
        skillId: 'addition-within-20',
        type: LearningActivityType.addObjects,
        title: 'Tambah sampai $limit',
        description: 'Gabungkan dua kelompok benda untuk mencari jumlahnya.',
        story: 'Pai Alvero butuh apel. Hitung semuanya sebelum dimasukkan!',
        actionLabel: 'Menambahkan apel',
        goalLine: 'Hitung semua apel untuk pai.',
        questions: questions,
        result: 'Pai apel hangat siap dinikmati bersama!',
        collectionCount: math.min(level + 3, 7),
        collectionLabel: 'apel',
        collectionPrompt: 'Masukkan apel',
        collectionButtonLabel: 'TAMBAHKAN KE PAI!',
        destinationLabel: 'ADONAN PAI',
        collectionEmoji: '🍎',
      );
    });
  }

  static LearningMission _mission({
    required int level,
    required String skillId,
    required LearningActivityType type,
    required String title,
    required String description,
    required String story,
    required String actionLabel,
    required String goalLine,
    required List<LearningQuestion> questions,
    required String result,
    int? collectionCount,
    String collectionLabel = 'benda',
    String collectionPrompt = '',
    String collectionButtonLabel = '',
    String destinationLabel = '',
    String collectionEmoji = '',
  }) {
    final themeIndex = switch (type) {
      LearningActivityType.findLetter => 0,
      LearningActivityType.identifyColor => 1,
      LearningActivityType.continuePattern => 2,
      LearningActivityType.countObjects => 3,
      LearningActivityType.addObjects => 4,
    };
    return LearningMission(
      id: '$skillId-level-${level + 1}',
      themeIndex: themeIndex,
      skillId: skillId,
      type: type,
      title: title,
      description: description,
      story: story,
      actionLabel: actionLabel,
      goalLine: goalLine,
      questions: questions,
      result: result,
      collectionCount: collectionCount,
      collectionLabel: collectionLabel,
      collectionPrompt: collectionPrompt,
      collectionButtonLabel: collectionButtonLabel,
      destinationLabel: destinationLabel,
      collectionEmoji: collectionEmoji,
    );
  }
}
