import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'audio/game_audio_policy.dart';
import 'game/learning_mission.dart';
import 'game/skill_progress.dart';

void main() => runApp(const PetualanganAlveroApp());

class PetualanganAlveroApp extends StatelessWidget {
  const PetualanganAlveroApp({super.key, this.audioEnabled = true});

  final bool audioEnabled;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Petualangan Alvero',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Trebuchet MS',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF48B774)),
    ),
    home: AlveroGamePage(audioEnabled: audioEnabled),
  );
}

class AlveroGamePage extends StatefulWidget {
  const AlveroGamePage({super.key, this.audioEnabled = true});

  final bool audioEnabled;

  @override
  State<AlveroGamePage> createState() => _AlveroGamePageState();
}

class _AlveroGamePageState extends State<AlveroGamePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _collectionDestinationIcons = <IconData>[
    Icons.shopping_basket_rounded,
    Icons.cruelty_free_rounded,
    Icons.bakery_dining_rounded,
    Icons.cruelty_free_rounded,
    Icons.bakery_dining_rounded,
  ];
  static const _resultCompanionIcons = <IconData>[
    Icons.park_rounded,
    Icons.local_florist_rounded,
    Icons.shopping_basket_rounded,
    Icons.cruelty_free_rounded,
    Icons.bakery_dining_rounded,
  ];
  static const _missionIcons = <IconData>[
    Icons.text_fields_rounded,
    Icons.palette_rounded,
    Icons.pattern_rounded,
    Icons.cruelty_free_rounded,
    Icons.bakery_dining_rounded,
  ];
  static const _journeyStops = <String>[
    'Kebun huruf',
    'Taman warna',
    'Jalur pola',
    'Padang kelinci',
    'Dapur pai',
  ];
  static const _journeyColors = <Color>[
    Color(0xFF9CDB6B),
    Color(0xFF7ED6C4),
    Color(0xFFFFC86A),
    Color(0xFFA8A7E8),
    Color(0xFFF2A0B4),
  ];
  static const _green = Color(0xFF35B66A);
  static const _ink = Color(0xFF243B35);
  int _round = 0;
  int _questionIndex = 0;
  int _picked = 0;
  int _stars = 0;
  int _wrongAttempts = 0;
  bool _hasUsedHint = false;
  bool _usedHintInMission = false;
  final Map<String, SkillProgress> _skillProgress = {};
  bool _showSplash = true;
  bool _showMap = false;
  bool _showMissionIntro = false;
  bool _showMissionComplete = false;
  bool _answerSelected = false;
  bool _readyNext = false;
  bool _finished = false;
  String _answerFeedback = '';
  bool _soundEnabled = true;
  AudioPlayer? _musicPlayer;
  AudioPlayer? _effectsPlayer;
  String _musicAsset = 'audio/alvero_music.wav';
  String? _loadedMusicAsset;
  bool _musicPlaying = false;
  bool _appInBackground = false;
  final Queue<String> _effectQueue = Queue<String>();
  bool _effectInProgress = false;
  late Future<void> _effectsAudioReady;
  final math.Random _answerRandom = math.Random();
  final ScrollController _mapScrollController = ScrollController();
  List<String> _shuffledAnswerOptions = [];
  int _previousCorrectAnswerSlot = -1;
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    lowerBound: 0.86,
    upperBound: 1,
  )..value = 1;
  late final AnimationController _mapFloat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  List<LearningMission> get _missions => LearningMission.catalog;
  LearningMission get _mission => _missions[_round];
  LearningQuestion get _question => _mission.questions[_questionIndex];
  int get _target => _mission.collectionCount ?? 0;
  List<String> get _answerOptions => _shuffledAnswerOptions;
  bool get _collectingItems =>
      _mission.usesObjectCollection &&
      _questionIndex == _mission.questions.length - 1 &&
      _answerSelected &&
      !_readyNext;
  String get _completionFeedback =>
      switch (_skillProgress[_mission.id]?.status) {
        SkillStatus.independent => 'Kamu menemukannya sendiri!',
        SkillStatus.completedWithHelp =>
          'Kamu berhasil dengan petunjuk Alvero!',
        _ => 'Kamu terus mencoba. Hebat!',
      };

  int get _activeStop => math.min(
    _stars ~/ (_missions.length ~/ _journeyStops.length),
    _journeyStops.length - 1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapFloat.repeat(reverse: true);
    if (widget.audioEnabled) {
      _musicPlayer = AudioPlayer();
      _effectsPlayer = AudioPlayer();
      _effectsAudioReady = _effectsPlayer!.setAudioContext(
        createAlveroEffectsAudioContext(),
      );
      unawaited(_startMusic());
    }
    _refreshAnswerOptions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInBackground = false;
      if (_effectInProgress) {
        unawaited(_effectsPlayer?.resume());
      } else if (_soundEnabled) {
        unawaited(_startMusic());
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appInBackground = true;
      _musicPlaying = false;
      unawaited(_musicPlayer?.pause());
      unawaited(_effectsPlayer?.pause());
    }
  }

  void _refreshAnswerOptions() {
    final options = [..._question.choices]..shuffle(_answerRandom);
    var correctSlot = options.indexOf(_question.correctAnswer);
    if (_previousCorrectAnswerSlot >= 0 &&
        correctSlot == _previousCorrectAnswerSlot) {
      final nextSlot =
          (correctSlot + 1 + _answerRandom.nextInt(options.length - 1)) %
          options.length;
      options[correctSlot] = options[nextSlot];
      options[nextSlot] = _question.correctAnswer;
      correctSlot = nextSlot;
    }
    _previousCorrectAnswerSlot = correctSlot;
    _shuffledAnswerOptions = options;
  }

  void _startAdventure() {
    _playEffect('audio/ui_tap.wav');
    _setMusicTrack('audio/alvero_music.wav');
    setState(() {
      _showSplash = false;
      _showMap = true;
      _showMissionIntro = false;
    });
  }

  void _enterMapLevel(int level) {
    if (level != _stars || _stars >= _missions.length) return;
    _playEffect('audio/ui_tap.wav');
    _setMusicTrack('audio/alvero_music.wav');
    final isNewRound = _round != level;
    setState(() {
      if (isNewRound) {
        _round = level;
        _questionIndex = 0;
        _picked = 0;
        _wrongAttempts = 0;
        _hasUsedHint = false;
        _usedHintInMission = false;
        _answerSelected = false;
        _readyNext = false;
        _answerFeedback = '';
      }
      _showSplash = false;
      _showMap = false;
      _showMissionIntro = true;
      _showMissionComplete = false;
      _finished = false;
    });
    if (isNewRound) _refreshAnswerOptions();
    _bounce.value = 1;
  }

  void _startMission() {
    _playEffect('audio/ui_tap.wav');
    _setMusicTrack('audio/alvero_mission_music.wav');
    setState(() => _showMissionIntro = false);
    _bounce.forward(from: .86).then((_) => _bounce.reverse());
  }

  void _returnToMap() {
    _playEffect('audio/ui_tap.wav');
    _setMusicTrack('audio/alvero_music.wav');
    _mapFloat.repeat(reverse: true);
    setState(() {
      _showMap = true;
      _showMissionIntro = false;
      _showMissionComplete = false;
    });
    _scrollToActiveLevel();
  }

  void _scrollToActiveLevel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapScrollController.hasClients) return;
      final target = (_stars * 98.0)
          .clamp(0.0, _mapScrollController.position.maxScrollExtent)
          .toDouble();
      _mapScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _toggleSound() async {
    final enabled = !_soundEnabled;
    setState(() => _soundEnabled = enabled);
    if (!widget.audioEnabled) return;
    if (enabled) {
      _playEffect('audio/ui_tap.wav');
      await _startMusic();
    } else {
      _effectQueue.clear();
      _musicPlaying = false;
      await _effectsPlayer!.stop();
      await _musicPlayer!.stop();
    }
  }

  void _setMusicTrack(String asset) {
    if (_musicAsset == asset) return;
    _musicAsset = asset;
    if (!_soundEnabled || _appInBackground) return;
    unawaited(_startMusic());
  }

  Future<void> _startMusic() async {
    final music = _musicPlayer;
    if (music == null || !_soundEnabled || _appInBackground) return;
    try {
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(.26);
      if (_loadedMusicAsset != _musicAsset) {
        await music.stop();
        await music.play(AssetSource(_musicAsset));
        _loadedMusicAsset = _musicAsset;
      } else if (!_musicPlaying) {
        await music.resume();
      }
      _musicPlaying = true;
    } on Object {
      // Browsers can reject autoplay before the first user gesture.
      _musicPlaying = false;
    }
  }

  Future<void> _playEffect(String asset) async {
    if (!_soundEnabled || !widget.audioEnabled) return;
    _effectQueue.addLast(asset);
    if (_effectInProgress) return;

    final effects = _effectsPlayer;
    if (!_soundEnabled || effects == null) return;

    _effectInProgress = true;
    try {
      await _effectsAudioReady;
      while (_soundEnabled && _effectQueue.isNotEmpty) {
        final effectAsset = _effectQueue.removeFirst();
        await effects.stop();
        final completed = effects.onPlayerStateChanged.firstWhere(
          (state) =>
              state == PlayerState.completed || state == PlayerState.stopped,
        );
        await effects.play(AssetSource(effectAsset));
        await completed;
      }
    } finally {
      _effectInProgress = false;
      if (_soundEnabled && mounted) {
        if (!_appInBackground &&
            (!_musicPlaying || _loadedMusicAsset != _musicAsset)) {
          await _startMusic();
        }
      }
    }
  }

  void _chooseAnswer(String answer) {
    if (_answerSelected) return;
    final correct = answer == _question.correctAnswer;
    setState(() {
      final progress = _skillProgress.putIfAbsent(
        _mission.id,
        SkillProgress.new,
      );
      progress.recordAnswer(
        correct: correct,
        hintUsed: _hasUsedHint || _usedHintInMission,
      );
      _answerFeedback = correct ? _question.feedback : '';
      if (correct) {
        _answerSelected = true;
        final finalQuestion = _questionIndex == _mission.questions.length - 1;
        if (finalQuestion && !_mission.usesObjectCollection) {
          _stars++;
          _readyNext = true;
          _showMissionComplete = true;
        }
      } else {
        _wrongAttempts++;
        _hasUsedHint = true;
        _usedHintInMission = true;
      }
    });
    if (correct) {
      _bounce.forward(from: 0.86).then((_) => _bounce.reverse());
      _playEffect('audio/star_jingle.wav');
    } else {
      _playEffect('audio/wrong_toot.wav');
      _showWrongAnswerDialog();
    }
  }

  void _advanceQuestion() {
    if (!_answerSelected || _questionIndex >= _mission.questions.length - 1) {
      return;
    }
    _playEffect('audio/ui_tap.wav');
    setState(() {
      _questionIndex++;
      _answerSelected = false;
      _wrongAttempts = 0;
      _hasUsedHint = false;
      _answerFeedback = '';
    });
    _refreshAnswerOptions();
    _bounce.forward(from: 0.86).then((_) => _bounce.reverse());
  }

  Future<void> _showWrongAnswerDialog() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      key: const ValueKey('wrong-answer-dialog'),
      backgroundColor: const Color(0xFFFFF9EE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE9B3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_rounded,
                size: 48,
                color: Color(0xFFE7A62F),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum tepat!',
              style: TextStyle(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _wrongAttempts > 1
                  ? 'Tidak apa-apa. Kita coba bersama, ya!'
                  : 'Ayo coba lagi. Alvero bantu, ya!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF658378),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1CC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: Color(0xFFE7A62F),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _question.hint,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Color(0xFF8E642F),
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  _playEffect('audio/ui_tap.wav');
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'COBA LAGI',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _collectMissionItem() {
    if (!_answerSelected || _finished || _readyNext || _picked >= _target) {
      return;
    }
    setState(() => _picked++);
    _bounce.forward(from: 0.86).then((_) => _bounce.reverse());
    _playEffect('audio/apple_pop.wav');
    if (_picked == _target) {
      setState(() {
        _stars++;
        _readyNext = true;
        _showMissionComplete = true;
      });
      _playEffect('audio/star_jingle.wav');
    }
  }

  void _continue() {
    _playEffect('audio/ui_tap.wav');
    _setMusicTrack('audio/alvero_music.wav');
    _mapFloat.repeat(reverse: true);
    setState(() {
      _showMap = true;
      _showMissionIntro = false;
      _showMissionComplete = false;
      if (_stars == _missions.length) {
        _finished = true;
      } else {
        _round = _stars;
        _questionIndex = 0;
        _picked = 0;
        _answerSelected = false;
        _readyNext = false;
        _wrongAttempts = 0;
        _hasUsedHint = false;
        _usedHintInMission = false;
        _answerFeedback = '';
      }
    });
    _scrollToActiveLevel();
    _refreshAnswerOptions();
  }

  void _restart() {
    _playEffect('audio/ui_tap.wav');
    _setMusicTrack('audio/alvero_music.wav');
    setState(() {
      _round = 0;
      _questionIndex = 0;
      _picked = 0;
      _stars = 0;
      _answerSelected = false;
      _readyNext = false;
      _wrongAttempts = 0;
      _hasUsedHint = false;
      _usedHintInMission = false;
      _finished = false;
      _answerFeedback = '';
      _showSplash = false;
      _showMap = true;
      _showMissionIntro = false;
      _showMissionComplete = false;
      _mapFloat.repeat(reverse: true);
    });
    _refreshAnswerOptions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bounce.dispose();
    _mapFloat.dispose();
    _mapScrollController.dispose();
    _musicPlayer?.dispose();
    _effectsPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9F5FF), Color(0xFFF4FCEB), Color(0xFFE9F8D7)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Padding(
                    padding: _showMissionIntro
                        ? EdgeInsets.zero
                        : EdgeInsets.symmetric(
                            horizontal: compact ? 18 : 36,
                            vertical: 14,
                          ),
                    child: Column(
                      children: [
                        if (!_showSplash &&
                            !_showMissionIntro &&
                            !_showMissionComplete) ...[
                          _topBar(compact),
                          const SizedBox(height: 14),
                        ],
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 480),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: .96,
                                      end: 1,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: _showSplash
                                ? _splashPage(compact)
                                : _showMissionIntro
                                ? _missionIntroPage(compact)
                                : _showMissionComplete
                                ? _missionCompletePage(compact)
                                : _showMap
                                ? _mapPage(compact)
                                : _gameplayLayout(compact),
                          ),
                        ),
                        if (!_showSplash &&
                            !_showMissionIntro &&
                            !_showMissionComplete)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'BELAJAR SAMBIL BERMAIN ✨',
                              style: TextStyle(
                                color: Color(0xFF6F9183),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _splashPage(bool compact) => Center(
    key: const ValueKey('splash-screen'),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 54 : 64,
            height: compact ? 54 : 64,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets_rounded, color: _green, size: 32),
          ),
          const SizedBox(height: 12),
          _splashMascot(compact ? 190 : 235),
          const SizedBox(height: 16),
          Text(
            'PETUALANGAN ALVERO',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: compact ? 26 : 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Hitung apel, bantu teman,\ndan kumpulkan bintang!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF658378),
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: compact ? 280 : 340,
            height: 60,
            child: ElevatedButton.icon(
              key: const ValueKey('start-adventure'),
              onPressed: _startAdventure,
              icon: const Icon(Icons.explore_rounded, size: 24),
              label: const Text(
                'MULAI PETUALANGAN',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '25 level seru menanti di peta Alvero',
            style: TextStyle(
              color: Color(0xFF7D998D),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _splashMascot(double size) => AnimatedBuilder(
    animation: _mapFloat,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -5 * _mapFloat.value),
      child: child,
    ),
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .82,
            height: size * .82,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC15A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x263A7147),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
          ),
          _cat(size * .78),
          Positioned(
            top: size * .05,
            right: size * .11,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFC83D),
              size: 30,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _missionIntroPage(bool compact) => LayoutBuilder(
    builder: (context, constraints) => Container(
      key: const ValueKey('mission-intro'),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _journeyColors[_mission.themeIndex].withValues(alpha: .22),
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 22 : 56,
              vertical: compact ? 18 : 30,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('intro-back-to-map'),
                      tooltip: 'Kembali ke peta',
                      onPressed: _returnToMap,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _green,
                        minimumSize: const Size(52, 52),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'LEVEL ${_round + 1} DARI ${_missions.length}',
                        style: const TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 24),
                _missionStage(math.min(constraints.maxWidth, 620.0), compact),
                SizedBox(height: compact ? 9 : 14),
                Text(
                  _mission.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: compact ? 25 : 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxWidth: 570),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 18 : 28,
                    vertical: compact ? 13 : 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x17315E47),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_rounded,
                            color: Color(0xFFFFC15A),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ALVERO BUTUH BANTUANMU',
                            style: TextStyle(
                              color: _green,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                              fontSize: compact ? 11 : 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _mission.story,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: compact ? 15 : 18,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6DD),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _missionIcons[_mission.themeIndex],
                              color: const Color(0xFFE7A62F),
                              size: 23,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _mission.goalLine,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF8E642F),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: compact ? double.infinity : 360,
                  height: 62,
                  child: ElevatedButton.icon(
                    key: const ValueKey('start-mission'),
                    onPressed: _startMission,
                    icon: const Icon(Icons.play_arrow_rounded, size: 27),
                    label: const Text(
                      'AYO BANTU ALVERO!',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _missionStage(double width, bool compact) => SizedBox(
    key: const ValueKey('mission-scene'),
    width: width,
    height: compact ? 250 : 320,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBDEFFF), Color(0xFFE5F8D5)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: compact ? 62 : 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _journeyColors[_mission.themeIndex],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(80),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * .09,
                top: constraints.maxHeight * .16,
                child: _cloud(compact ? 52 : 68),
              ),
              Positioned(
                right: constraints.maxWidth * .1,
                top: constraints.maxHeight * .23,
                child: _cloud(compact ? 42 : 58),
              ),
              Positioned(
                left: constraints.maxWidth * .1,
                bottom: compact ? 24 : 32,
                child: Icon(
                  _missionIcons[_mission.themeIndex],
                  key: const ValueKey('mission-prop'),
                  size: compact ? 66 : 88,
                  color: const Color(0xFFB87635),
                ),
              ),
              Positioned(
                right: constraints.maxWidth * .1,
                bottom: compact ? 30 : 38,
                child: AnimatedBuilder(
                  animation: _mapFloat,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -10 * _mapFloat.value),
                    child: Transform.rotate(
                      angle: -.12 + .24 * _mapFloat.value,
                      child: child,
                    ),
                  ),
                  child: Icon(
                    _missionIcons[_mission.themeIndex],
                    size: compact ? 48 : 60,
                    color: _journeyColors[_mission.themeIndex],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _mapFloat,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -7 * _mapFloat.value),
                  child: child,
                ),
                child: Container(
                  width: compact ? 132 : 166,
                  height: compact ? 132 : 166,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC15A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x263A7147),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Center(child: _catFace(compact ? 96 : 122)),
                ),
              ),
              Positioned(
                top: 12,
                right: 14,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFC83D),
                  size: 28,
                ),
              ),
              Positioned(
                top: 15,
                left: 16,
                child: Icon(
                  Icons.local_florist_rounded,
                  color: const Color(0xFFFFC950).withValues(alpha: .9),
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _missionCompletePage(bool compact) => LayoutBuilder(
    builder: (context, constraints) => Container(
      key: const ValueKey('mission-complete'),
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6D8), Color(0xFFE4F8D7), Color(0xFFD6F4E4)],
        ),
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 22 : 56,
              vertical: compact ? 18 : 30,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'LEVEL ${_round + 1} SELESAI',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .9,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 12 : 20),
                _missionResultStage(
                  math.min(constraints.maxWidth, 620.0),
                  compact,
                ),
                SizedBox(height: compact ? 12 : 18),
                Text(
                  'MISI BERHASIL!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _green,
                    fontSize: compact ? 27 : 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 570),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 18 : 28,
                    vertical: compact ? 15 : 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x17315E47),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _mapFloat,
                        builder: (context, child) => Transform.scale(
                          scale: .9 + .1 * _mapFloat.value,
                          child: child,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFC83D),
                          size: 46,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _mission.result,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: compact ? 17 : 21,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _completionFeedback,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF658378),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 14 : 20),
                SizedBox(
                  width: compact ? double.infinity : 360,
                  height: 62,
                  child: ElevatedButton.icon(
                    key: const ValueKey('continue-to-map'),
                    onPressed: _continue,
                    icon: const Icon(Icons.map_rounded, size: 23),
                    label: const Text(
                      'LANJUT KE PETA',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _missionResultStage(double width, bool compact) => SizedBox(
    key: const ValueKey('mission-result-scene'),
    width: width,
    height: compact ? 245 : 310,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFEFFF), Color(0xFFE9F8D9)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: compact ? 58 : 78,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _journeyColors[_mission.themeIndex],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(80),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: constraints.maxWidth * .12,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: const Color(0xFFFFC83D),
                  size: compact ? 30 : 40,
                ),
              ),
              Positioned(
                top: 28,
                right: constraints.maxWidth * .13,
                child: Icon(
                  Icons.star_rounded,
                  color: const Color(0xFFFFC83D).withValues(alpha: .8),
                  size: compact ? 24 : 32,
                ),
              ),
              Positioned(
                left: constraints.maxWidth * .13,
                bottom: compact ? 20 : 28,
                child: AnimatedBuilder(
                  animation: _mapFloat,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -16 * _mapFloat.value),
                    child: Transform.rotate(
                      angle: -.2 + .4 * _mapFloat.value,
                      child: child,
                    ),
                  ),
                  child: Icon(
                    _resultCompanionIcons[_mission.themeIndex],
                    size: compact ? 58 : 76,
                    color: const Color(0xFF8F795D),
                  ),
                ),
              ),
              Positioned(
                right: constraints.maxWidth * .13,
                bottom: compact ? 25 : 32,
                child: AnimatedBuilder(
                  animation: _mapFloat,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -11 * (1 - _mapFloat.value)),
                    child: child,
                  ),
                  child: Icon(
                    _missionIcons[_mission.themeIndex],
                    size: compact ? 48 : 60,
                    color: _journeyColors[_mission.themeIndex],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _mapFloat,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -9 * _mapFloat.value),
                  child: child,
                ),
                child: Container(
                  width: compact ? 122 : 154,
                  height: compact ? 122 : 154,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC15A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x263A7147),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Center(child: _catFace(compact ? 88 : 112)),
                ),
              ),
              Positioned(
                top: 22,
                child: Icon(
                  Icons.favorite_rounded,
                  color: const Color(0xFFFF8CA1).withValues(alpha: .9),
                  size: compact ? 22 : 28,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _mapPage(bool compact) {
    final complete = _stars >= _missions.length;
    return Column(
      children: [
        Text(
          complete ? 'PETUALANGAN SELESAI!' : 'PETA PETUALANGAN',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _green,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          complete
              ? 'Alvero sudah mengunjungi semua tempat!'
              : 'Lima tempat seru dan 25 level menantimu',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF658378),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boardHeight = math.max(
                constraints.maxHeight,
                (_missions.length - 1) * 105.0 + 140,
              );
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const PageStorageKey('alvero-adventure-map'),
                      controller: _mapScrollController,
                      reverse: true,
                      child: SizedBox(
                        height: boardHeight,
                        child: _mapBoard(compact, boardHeight),
                      ),
                    ),
                  ),
                  if (complete)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: _finishContent(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 2),
                      child: Text(
                        'Tujuan: ${_journeyStops[_activeStop]} · ${_stars + 1} / ${_missions.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF718B7E),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mapBoard(bool compact, double height) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 560.0);
      final nodeWidth = math.min(width * .38, compact ? 132.0 : 150.0);
      final nodeHeight = 94.0;
      final nodePoints = List.generate(
        _missions.length,
        (index) => _levelMapPoint(index, _missions.length),
      );
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDBF6ED), Color(0xFFD9F0C3)],
              ),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WindingPathPainter(
                        completedStops: _stars,
                        levelCount: _missions.length,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    left: width * .08,
                    child: Icon(
                      Icons.cloud_rounded,
                      color: Colors.white.withValues(alpha: .8),
                      size: 40,
                    ),
                  ),
                  Positioned(
                    top: height * .38,
                    right: width * .06,
                    child: Icon(
                      Icons.park_rounded,
                      color: const Color(0xFF72B77C).withValues(alpha: .45),
                      size: 45,
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: width * .05,
                    child: Icon(
                      Icons.local_florist_rounded,
                      color: const Color(0xFFFFC950).withValues(alpha: .8),
                      size: 34,
                    ),
                  ),
                  for (var index = 0; index < _missions.length; index++)
                    Positioned(
                      left: width * nodePoints[index].dx - nodeWidth / 2,
                      top: height * nodePoints[index].dy - nodeHeight / 2,
                      width: nodeWidth,
                      height: nodeHeight,
                      child: _mapLevelNode(index),
                    ),
                  if (_stars < _missions.length)
                    Positioned(
                      left: _travelerLeft(width, width * nodePoints[_stars].dx),
                      top: height * nodePoints[_stars].dy - 42,
                      child: _mapTraveler(compact, missionIndex: _stars),
                    ),
                  if (_stars >= _missions.length)
                    Positioned(
                      left: width * nodePoints.last.dx + 34,
                      top: height * nodePoints.last.dy - 32,
                      child: _mapTraveler(
                        compact,
                        celebrating: true,
                        missionIndex: _missions.length - 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  double _travelerLeft(double width, double nodeX) {
    final center = nodeX < width / 2 ? nodeX + 100 : nodeX - 100;
    return (center - 31).clamp(6, width - 68).toDouble();
  }

  Widget _mapLevelNode(int index) {
    final completed = index < _stars;
    final active = index == _stars && _stars < _missions.length;
    return Semantics(
      button: active,
      enabled: active,
      label:
          'Level ${index + 1}, ${_missions[index].title}, ${completed
              ? 'selesai'
              : active
              ? 'siap dimainkan'
              : 'terkunci'}',
      child: InkWell(
        key: ValueKey('map-level-$index'),
        onTap: active ? () => _enterMapLevel(index) : null,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? .94 : .72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active
                  ? const Color(0xFFFFC83D)
                  : completed
                  ? const Color(0xFF6CCB8A)
                  : Colors.white.withValues(alpha: .7),
              width: active ? 3 : 2,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x3035B66A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: completed
                      ? _green
                      : active
                      ? const Color(0xFFFFD875)
                      : const Color(0xFFE4ECE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed
                      ? Icons.check_rounded
                      : active
                      ? _missionIcons[_missions[index].themeIndex]
                      : Icons.lock_rounded,
                  color: completed
                      ? Colors.white
                      : active
                      ? _green
                      : const Color(0xFF91A59A),
                  size: 23,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'LEVEL ${index + 1}',
                style: TextStyle(
                  color: active ? _green : const Color(0xFF658378),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _missions[index].title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: completed || active ? _ink : const Color(0xFF879A90),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapTraveler(
    bool compact, {
    bool celebrating = false,
    required int missionIndex,
  }) => AnimatedBuilder(
    animation: _mapFloat,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -5 * _mapFloat.value),
      child: child,
    ),
    child: Semantics(
      label:
          'Alvero ${celebrating ? 'merayakan petualangan' : _missions[missionIndex].actionLabel}',
      child: SizedBox(
        width: compact ? 62 : 72,
        height: compact ? 62 : 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: compact ? 58 : 68,
              height: compact ? 58 : 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC15A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x283A7147),
                    blurRadius: 9,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(child: _catFace(compact ? 37 : 44)),
            ),
            Positioned(
              right: -1,
              top: -3,
              child: Container(
                width: 25,
                height: 25,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  celebrating
                      ? Icons.celebration_rounded
                      : _missionIcons[_missions[missionIndex].themeIndex],
                  size: 15,
                  color: const Color(0xFFEE9C38),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _gameplayLayout(bool compact) => compact
      ? _mobileLayout()
      : Row(
          children: [
            Expanded(flex: 4, child: _alveroScene()),
            const SizedBox(width: 28),
            Expanded(flex: 5, child: _gameCard()),
          ],
        );

  Widget _mobileLayout() => Column(
    children: [
      Expanded(flex: 3, child: _alveroScene()),
      const SizedBox(height: 8),
      Expanded(flex: 7, child: _gameCard()),
    ],
  );

  Widget _topBar(bool compact) => Row(
    children: [
      if (!_showMap)
        IconButton(
          key: const ValueKey('back-to-map'),
          tooltip: 'Kembali ke peta',
          onPressed: _returnToMap,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .85),
            foregroundColor: _green,
            minimumSize: Size(compact ? 44 : 52, compact ? 44 : 52),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        )
      else
        Container(
          width: compact ? 44 : 52,
          height: compact ? 44 : 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pets_rounded, color: _green, size: 27),
        ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PETUALANGAN ALVERO',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                fontSize: compact ? 14 : 17,
              ),
            ),
            const Text(
              'Kebun apel ajaib',
              style: TextStyle(
                color: Color(0xFF658378),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        key: const ValueKey('sound-toggle'),
        tooltip: _soundEnabled ? 'Matikan suara' : 'Nyalakan suara',
        onPressed: _toggleSound,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _green,
          minimumSize: const Size(48, 48),
        ),
        icon: Icon(
          _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        ),
      ),
      const SizedBox(width: 8),
      _pill(Icons.star_rounded, '$_stars', const Color(0xFFFFC83D)),
    ],
  );

  Widget _pill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12345544),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _alveroScene() => LayoutBuilder(
    builder: (context, box) {
      final size = math.min(box.maxHeight, box.maxWidth * 1.3);
      return Center(
        child: SizedBox(
          width: size,
          height: math.min(box.maxHeight, size * .98),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 4,
                left: size * .04,
                right: size * .04,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  height: size * .37,
                  decoration: BoxDecoration(
                    color: _journeyColors[_activeStop],
                    borderRadius: BorderRadius.circular(size * .45),
                  ),
                ),
              ),
              Positioned(
                top: size * .06,
                left: size * .07,
                child: _cloud(size * .16),
              ),
              Positioned(
                top: size * .19,
                right: size * .08,
                child: _cloud(size * .13),
              ),
              Positioned(
                left: size * .04,
                bottom: size * .18,
                child: const Icon(
                  Icons.local_florist_rounded,
                  color: Color(0xFFFFC950),
                  size: 31,
                ),
              ),
              Positioned(
                right: size * .09,
                bottom: size * .16,
                child: const Icon(
                  Icons.filter_vintage_rounded,
                  color: Color(0xFFFF8CA1),
                  size: 29,
                ),
              ),
              Positioned(
                bottom: size * .18,
                child: AnimatedBuilder(
                  animation: _bounce,
                  builder: (context, child) =>
                      Transform.scale(scale: _bounce.value, child: child),
                  child: SizedBox(
                    key: const ValueKey('mission-character'),
                    child: _cat(size * .72),
                  ),
                ),
              ),
              Positioned(
                top: size * .02,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    key: const ValueKey('mission-action'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _missionIcons[_mission.themeIndex],
                          color: _green,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _mission.actionLabel,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: size * .16,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFC83D),
                  size: 25,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _cloud(double size) => Container(
    width: size,
    height: size * .34,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(30),
    ),
  );

  Widget _cat(double size) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .82,
            height: size * .74,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC15A),
              borderRadius: BorderRadius.circular(size * .37),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x243A7147),
                  blurRadius: 18,
                  offset: Offset(0, 9),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: size * .07,
            child: Transform.rotate(angle: -.23, child: _ear(size * .25)),
          ),
          Positioned(
            top: 0,
            right: size * .07,
            child: Transform.rotate(angle: .23, child: _ear(size * .25)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _catFace(size * .48),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ALVERO',
                  style: TextStyle(
                    color: Color(0xFF8E5B28),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 6),
      Container(
        width: size * .73,
        height: 17,
        decoration: BoxDecoration(
          color: const Color(0xFF63B842),
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ],
  );

  Widget _ear(double size) => ClipPath(
    clipper: _TriangleClipper(),
    child: Container(width: size, height: size, color: const Color(0xFFFFC15A)),
  );

  Widget _catFace(double size) => CustomPaint(
    size: Size(size, size * .78),
    painter: const _CatFacePainter(),
  );

  Widget _gameCard() => Container(
    width: double.infinity,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 680 ? 18 : 24),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x17315E47),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: _finished ? _finishContent() : _roundContent(),
  );

  Widget _roundContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'LEVEL ${_round + 1} · ${_mission.title.toUpperCase()}',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            'SOAL ${_questionIndex + 1} / ${_mission.questions.length}',
            style: const TextStyle(
              color: Color(0xFF789189),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: LinearProgressIndicator(
          value: (_questionIndex + 1) / _mission.questions.length,
          minHeight: 8,
          backgroundColor: const Color(0xFFEAF3EC),
          color: const Color(0xFFFFC83D),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              _missionIcons[_mission.themeIndex],
              color: const Color(0xFFD99428),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mission.title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _mission.description,
                    style: const TextStyle(
                      color: Color(0xFF789189),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (_question.visual.isNotEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              _question.visual,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      Center(
        child: Text(
          _question.prompt,
          key: const ValueKey('math-question'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _green,
            fontWeight: FontWeight.w900,
            fontSize: _mission.type == LearningActivityType.addObjects
                ? 28
                : 25,
            letterSpacing: .3,
          ),
        ),
      ),
      const SizedBox(height: 3),
      Center(
        child: Text(
          _collectingItems
              ? 'Terkumpul: $_picked / $_target ${_mission.collectionLabel}'
              : _answerSelected
              ? _answerFeedback
              : 'Soal ${_questionIndex + 1} dari ${_mission.questions.length}',
          style: const TextStyle(
            color: Color(0xFF789189),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(height: 7),
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: !_answerSelected
              ? _answerChoices()
              : _collectingItems
              ? Center(
                  key: const ValueKey('collect-mission-items'),
                  child: _collectionScene(),
                )
              : _correctAnswerNotice(),
        ),
      ),
      const SizedBox(height: 8),
      if (_answerSelected)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _collectingItems
                ? _collectMissionItem
                : _advanceQuestion,
            icon: Icon(
              _collectingItems
                  ? _collectionDestinationIcons[_mission.themeIndex]
                  : Icons.arrow_forward_rounded,
              size: 23,
            ),
            label: Text(
              _collectingItems ? _mission.collectionButtonLabel : 'LANJUT SOAL',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
          ),
        )
      else
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Center(
            child: Text(
              'Pilih jawaban yang tepat untuk membantu Alvero!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFD67A55),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _correctAnswerNotice() => Center(
    key: const ValueKey('question-correct-feedback'),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 50),
          const SizedBox(height: 8),
          Text(
            _answerFeedback,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Soal ${_questionIndex + 1} dari ${_mission.questions.length} selesai',
            style: const TextStyle(
              color: Color(0xFF658378),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _answerChoices() => Center(
    child: Row(
      children: _answerOptions.map((answer) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              key: ValueKey('answer-$answer'),
              onPressed: () => _chooseAnswer(answer),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _green,
                side: const BorderSide(color: Color(0xFFCDE8D2)),
                minimumSize: const Size(0, 70),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    answer,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: answer.length > 5 ? 15 : 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_mission.usesObjectCollection)
                    Text(
                      _mission.collectionLabel,
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  String _collectionEmoji(int index) => switch (_mission.themeIndex) {
    3 => '🥕',
    4 => ['🍎', '🍊', '🍐', '🍇'][index % 4],
    _ => _mission.collectionEmoji,
  };

  Widget _collectionScene() => AnimatedBuilder(
    animation: _bounce,
    builder: (context, child) =>
        Transform.scale(scale: _bounce.value, child: child),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 350),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE8A4), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 2,
            children: List.generate(
              _target,
              (i) => Semantics(
                key: ValueKey('collection-item-$i'),
                label: i < _picked
                    ? '${_mission.collectionLabel} sudah digunakan'
                    : '${_mission.collectionPrompt} ${i + 1}',
                button: i == _picked && !_readyNext,
                child: GestureDetector(
                  onTap: i == _picked && !_readyNext
                      ? _collectMissionItem
                      : null,
                  child: AnimatedOpacity(
                    opacity: i < _picked ? 1 : .5,
                    duration: const Duration(milliseconds: 250),
                    child: _mission.themeIndex == 4
                        ? CustomPaint(
                            size: Size(
                              MediaQuery.sizeOf(context).width < 680 ? 28 : 34,
                              MediaQuery.sizeOf(context).width < 680 ? 31 : 37,
                            ),
                            painter: const _ApplePainter(),
                          )
                        : Text(
                            _collectionEmoji(i),
                            style: TextStyle(
                              fontSize: MediaQuery.sizeOf(context).width < 680
                                  ? 29
                                  : 36,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _collectionDestinationIcons[_mission.themeIndex],
                color: const Color(0xFFB87635),
                size: 19,
              ),
              const SizedBox(width: 7),
              Text(
                _mission.destinationLabel,
                style: const TextStyle(
                  color: Color(0xFF8E642F),
                  fontSize: 10,
                  letterSpacing: .6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            height: 8,
            width: 175,
            decoration: BoxDecoration(
              color: const Color(0xFFC17C3C),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 13,
            width: 188,
            decoration: BoxDecoration(
              color: const Color(0xFFE8AC57),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _finishContent() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.celebration_rounded,
          color: Color(0xFFFFC83D),
          size: 64,
        ),
        const SizedBox(height: 8),
        const Text(
          'Hebat sekali!',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Alvero bangga padamu!',
          style: TextStyle(
            color: Color(0xFF718B7E),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _stars,
            (_) => const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFC83D),
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay_rounded),
            label: const Text(
              'MAIN LAGI',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Offset _levelMapPoint(int index, int count) {
  const xPositions = [.2, .77, .24, .78, .47];
  final progress = count <= 1 ? 0.0 : index / (count - 1);
  return Offset(xPositions[index % xPositions.length], .95 - .9 * progress);
}

class _WindingPathPainter extends CustomPainter {
  const _WindingPathPainter({
    required this.completedStops,
    required this.levelCount,
  });

  final int completedStops;
  final int levelCount;

  @override
  void paint(Canvas canvas, Size size) {
    final points = List.generate(
      levelCount,
      (index) => _levelMapPoint(index, levelCount),
    );
    final route = Path()
      ..moveTo(size.width * points.first.dx, size.height * points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];
      route.cubicTo(
        size.width * from.dx,
        size.height * (from.dy + to.dy) / 2,
        size.width * to.dx,
        size.height * (from.dy + to.dy) / 2,
        size.width * to.dx,
        size.height * to.dy,
      );
    }

    final shadow = Paint()
      ..color = const Color(0x33578342)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final road = Paint()
      ..color = const Color(0xFFFFD36A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 21
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(route, shadow);
    canvas.drawPath(route, road);
    if (completedStops > 0) {
      final traveled = Paint()
        ..color = const Color(0xFF79C96B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      final metrics = route.computeMetrics().first;
      canvas.drawPath(
        metrics.extractPath(
          0,
          metrics.length *
              (completedStops.clamp(0, levelCount - 1) / (levelCount - 1)),
        ),
        traveled,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WindingPathPainter oldDelegate) =>
      completedStops != oldDelegate.completedStops ||
      levelCount != oldDelegate.levelCount;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .08, size.height)
    ..lineTo(size.width * .45, 0)
    ..lineTo(size.width * .94, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ApplePainter extends CustomPainter {
  const _ApplePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final redPaint = Paint()..color = const Color(0xFFE94F48);
    final apple = Path()
      ..moveTo(size.width * .5, size.height * .25)
      ..cubicTo(
        size.width * .2,
        size.height * .05,
        size.width * .02,
        size.height * .3,
        size.width * .12,
        size.height * .58,
      )
      ..cubicTo(
        size.width * .22,
        size.height * .91,
        size.width * .4,
        size.height * .96,
        size.width * .5,
        size.height * .82,
      )
      ..cubicTo(
        size.width * .6,
        size.height * .96,
        size.width * .8,
        size.height * .91,
        size.width * .88,
        size.height * .58,
      )
      ..cubicTo(
        size.width * .98,
        size.height * .3,
        size.width * .8,
        size.height * .05,
        size.width * .5,
        size.height * .25,
      )
      ..close();
    canvas.drawPath(apple, redPaint);

    final stemPaint = Paint()
      ..color = const Color(0xFF79502D)
      ..strokeWidth = size.width * .07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .5, size.height * .25),
      Offset(size.width * .54, size.height * .1),
      stemPaint,
    );

    final leaf = Path()
      ..moveTo(size.width * .52, size.height * .17)
      ..quadraticBezierTo(
        size.width * .72,
        size.height * .01,
        size.width * .82,
        size.height * .17,
      )
      ..quadraticBezierTo(
        size.width * .65,
        size.height * .26,
        size.width * .52,
        size.height * .17,
      )
      ..close();
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF55A956));
    canvas.drawCircle(
      Offset(size.width * .3, size.height * .44),
      size.width * .055,
      Paint()..color = const Color(0xFFFFAAA0),
    );
  }

  @override
  bool shouldRepaint(covariant _ApplePainter oldDelegate) => false;
}

class _CatFacePainter extends CustomPainter {
  const _CatFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFFFF0D0);
    final innerEar = Paint()..color = const Color(0xFFF59C9C);
    final leftEar = Path()
      ..moveTo(size.width * .08, size.height * .38)
      ..lineTo(size.width * .16, size.height * .02)
      ..lineTo(size.width * .42, size.height * .28)
      ..close();
    final rightEar = Path()
      ..moveTo(size.width * .58, size.height * .28)
      ..lineTo(size.width * .84, size.height * .02)
      ..lineTo(size.width * .92, size.height * .38)
      ..close();
    canvas.drawPath(leftEar, fill);
    canvas.drawPath(rightEar, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .08,
          size.height * .18,
          size.width * .84,
          size.height * .78,
        ),
        Radius.circular(size.width * .3),
      ),
      fill,
    );
    final leftPink = Path()
      ..moveTo(size.width * .18, size.height * .29)
      ..lineTo(size.width * .2, size.height * .1)
      ..lineTo(size.width * .34, size.height * .27)
      ..close();
    final rightPink = Path()
      ..moveTo(size.width * .66, size.height * .27)
      ..lineTo(size.width * .8, size.height * .1)
      ..lineTo(size.width * .82, size.height * .29)
      ..close();
    canvas.drawPath(leftPink, innerEar);
    canvas.drawPath(rightPink, innerEar);

    final dark = Paint()..color = const Color(0xFF59412F);
    canvas.drawCircle(
      Offset(size.width * .34, size.height * .56),
      size.width * .035,
      dark,
    );
    canvas.drawCircle(
      Offset(size.width * .66, size.height * .56),
      size.width * .035,
      dark,
    );
    final nose = Path()
      ..moveTo(size.width * .46, size.height * .65)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .71,
        size.width * .54,
        size.height * .65,
      )
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFE68188));
    final smile = Paint()
      ..color = const Color(0xFF75533B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .018
      ..strokeCap = StrokeCap.round;
    final mouth = Path()
      ..moveTo(size.width * .5, size.height * .7)
      ..quadraticBezierTo(
        size.width * .44,
        size.height * .79,
        size.width * .38,
        size.height * .73,
      )
      ..moveTo(size.width * .5, size.height * .7)
      ..quadraticBezierTo(
        size.width * .56,
        size.height * .79,
        size.width * .62,
        size.height * .73,
      );
    canvas.drawPath(mouth, smile);
  }

  @override
  bool shouldRepaint(covariant _CatFacePainter oldDelegate) => false;
}
