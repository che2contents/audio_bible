import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/bible_repository.dart';

class ReadingScreenArgs {
  final String dateKey; // 2026-02-02
  final String label; // "창 1-4"
  final String book; // "창세기"
  final int startChapter;
  final int endChapter;

  /// 오디오 에셋 경로 (없으면 null)
  /// 예: 'audio/gen1-4.mp3'  (assets/ 붙이면 안 됨)
  final String? audioAsset;

  ReadingScreenArgs({
    required this.dateKey,
    required this.label,
    required this.book,
    required this.startChapter,
    required this.endChapter,
    this.audioAsset,
  });
}

class ReadingScreen extends StatefulWidget {
  final ReadingScreenArgs args;
  const ReadingScreen({super.key, required this.args});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final BibleRepository _repo = BibleRepository();
  final ScrollController _controller = ScrollController();

  // ✅ 오디오
  late final AudioPlayer _player;
  bool _isPlaying = false;

  // ✅ 폰트 스케일(1.2 / 1.5 / 2.0)
  static const List<double> _fontSteps = [1.2, 1.5, 2.0];
  double _fontScale = 1.2;

  Map<String, dynamic>? _bookJson;
  bool _loading = true;
  String? _error;

  late int _chapter;
  bool _atBottom = false;

  @override
  void initState() {
    super.initState();
    _chapter = widget.args.startChapter;

    _player = AudioPlayer();

    // ✅ 재생 종료되면 버튼 상태 복귀
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
    });

    _controller.addListener(_onScroll);
    _loadBook();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final max = _controller.position.maxScrollExtent;
    final cur = _controller.position.pixels;

    // ✅ 스크롤이 없을 정도로 짧으면(max==0) 이미 끝까지 읽은 것으로 간주
    final atBottom = max == 0 || cur >= max - 24;

    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
  }

  Future<void> _loadBook() async {
    try {
      final json = await _repo.loadBook(widget.args.book);
      if (!mounted) return;
      setState(() {
        _bookJson = json;
        _loading = false;
      });

      // ✅ 첫 렌더 후에도 maxScrollExtent가 0인지 재판단(웹에서 특히)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onScroll();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _nextOrFinish() {
    final a = widget.args;

    if (_chapter < a.endChapter) {
      setState(() {
        _chapter++;
        _atBottom = false; // ✅ 다음 장으로 갈 때 버튼 상태 초기화
      });

      // 스크롤 맨 위로
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }

      // ✅ 다음 프레임에서 다시 하단 여부 체크
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onScroll();
      });
    } else {
      // ✅ 끝까지 읽음
      Navigator.pop(context, true);
    }
  }

  void _prevChapter() {
    final a = widget.args;
    if (_chapter <= a.startChapter) return;

    setState(() {
      _chapter--;
      _atBottom = false; // ✅ 이전 장으로 갈 때 버튼 상태 초기화
    });

    // 스크롤 맨 위로
    if (_controller.hasClients) {
      _controller.jumpTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onScroll();
    });
  }

  // =========================
  // ✅ 오디오 컨트롤(재생 누를 때만 로드/재생)
  // =========================
  Future<void> _togglePlay() async {
    final asset = widget.args.audioAsset;

    if (asset == null || asset.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해당 진도의 오디오가 없습니다.')),
      );
      return;
    }

    // ✅ 안전장치: 혹시 assets/ 붙어서 넘어오면 제거
    final src =
        asset.startsWith('assets/') ? asset.replaceFirst('assets/', '') : asset;

    try {
      if (_isPlaying) {
        await _player.pause();
        if (!mounted) return;
        setState(() => _isPlaying = false);
      } else {
        debugPrint("PLAYING_ASSET=$src");
        await _player.play(AssetSource(src));
        if (!mounted) return;
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint("PLAY_ERROR=$e");
      if (!mounted) return;
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오디오 재생에 실패했습니다.')),
      );
    }
  }

  // =========================
  // ✅ 글씨 크기 -/+
  // =========================
  void _zoomOut() {
    final idx = _fontSteps.indexOf(_fontScale);
    if (idx > 0) setState(() => _fontScale = _fontSteps[idx - 1]);
  }

  void _zoomIn() {
    final idx = _fontSteps.indexOf(_fontScale);
    if (idx >= 0 && idx < _fontSteps.length - 1) {
      setState(() => _fontScale = _fontSteps[idx + 1]);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(), // ✅ 좌측 상단 뒤로가기 상시
        title: Text('${a.book} $_chapter장'),
        actions: [
          // ✅ 오디오 버튼(오디오 있는 날만 활성)
          IconButton(
            onPressed: (a.audioAsset == null || a.audioAsset!.trim().isEmpty)
                ? null
                : _togglePlay,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            tooltip: _isPlaying ? '일시정지' : '재생',
          ),
          // ✅ 글씨 작게/크게 (1.2/1.5/2.0)
          IconButton(
            onPressed: _zoomOut,
            icon: const Icon(Icons.text_decrease),
            tooltip: '글씨 작게',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('${_fontScale}x'),
            ),
          ),
          IconButton(
            onPressed: _zoomIn,
            icon: const Icon(Icons.text_increase),
            tooltip: '글씨 크게',
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '범위: ${a.label}  (${_chapter - a.startChapter + 1}/${a.endChapter - a.startChapter + 1}장)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(child: Text('로드 실패: $_error'))
              : _buildChapterScaled(),

      // ✅ 하단: "이전 장" + "다음 장/완료"
      // - 이전 장: 시작 장이면 비활성
      // - 다음 장/완료: 끝까지 읽었을 때(_atBottom)만 활성
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _chapter > a.startChapter ? _prevChapter : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('이전 장'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _atBottom ? _nextOrFinish : null,
                  icon: Icon(
                    _chapter < a.endChapter ? Icons.chevron_right : Icons.check,
                  ),
                  label: Text(_chapter < a.endChapter ? '다음 장' : '완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterScaled() {
    // ✅ 본문 전체에 스케일 적용(1.2/1.5/2.0)
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_fontScale),
      ),
      child: _buildChapter(),
    );
  }

  Widget _buildChapter() {
  final verses = _repo.chapterVerses(_bookJson!, _chapter);

  return ListView(
    controller: _controller,
    padding: const EdgeInsets.all(16),
    children: [
      if (verses.isEmpty)
        const Text('이 장 데이터가 없습니다. (JSON에 해당 장 키가 있는지 확인)')
      else
        ...List.generate(verses.length, (index) {
          final verseNo = index + 1;
          final verseText = verses[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichText(
              textScaler: MediaQuery.of(context).textScaler,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 16,
                      height: 1.45,
                      color: Colors.black,
                    ),
                children: [
                  TextSpan(
                    text: '$verseNo ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  TextSpan(text: verseText),
                ],
              ),
            ),
          );
        }),
      const SizedBox(height: 120),
    ],
  );
}
