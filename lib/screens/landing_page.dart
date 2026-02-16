import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/feb_plan_2026.dart';
import '../services/progress_store.dart';
import '../services/audio_resolver.dart';
import 'reading_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _store = ProgressStore();

  final int year = 2026;
  final int month = 2;
  final int daysInMonth = 28;

  int _selectedDay = 1;
  bool _selectedDone = false;

  String _dateKey(int day) =>
      "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

  DayPlan? _planFor(int day) => FebPlan2026.plan[_dateKey(day)];

  @override
  void initState() {
    super.initState();
    _refreshSelectedDone();
  }

  Future<void> _refreshSelectedDone() async {
    final done = await _store.isDone(_dateKey(_selectedDay));
    if (!mounted) return;
    setState(() => _selectedDone = done);
  }

  Future<void> _onTapDay(int day) async {
    setState(() => _selectedDay = day);
    await _refreshSelectedDone();
  }

  Future<void> _onRead() async {
    final plan = _planFor(_selectedDay);
    if (plan == null || !plan.hasReading) return;

    final r = plan.ranges.first;

    // ✅ 오디오 파일 경로 자동 생성 (없으면 null)
    final audioAsset = AudioResolver.forRange(
      book: r.book,
      startChapter: r.startChapter,
      endChapter: r.endChapter,
    );

    final finished = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          args: ReadingScreenArgs(
            dateKey: _dateKey(_selectedDay),
            label: plan.label.replaceAll("\n", " "),
            book: r.book,
            startChapter: r.startChapter,
            endChapter: r.endChapter,
            audioAsset: audioAsset,
          ),
        ),
      ),
    );

    if (finished == true) {
      await _store.setDone(_dateKey(_selectedDay), true);
      await _refreshSelectedDone();
    }
  }

  // ✅ 시청하기 누르면: 유튜브 열고 -> 바로 완료 처리
  Future<void> _onWatch(String url) async {
    final key = _dateKey(_selectedDay);
    final uri = Uri.parse(url);

    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);

    await _store.setDone(key, true);

    if (!mounted) return;
    setState(() => _selectedDone = true);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL을 열 수 없습니다. (완료는 체크됨)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _planFor(_selectedDay);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            width: double.infinity,
            height: 160,
            child: Image.asset(
              'assets/images/che2_banner.png',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ 타이틀 (요구사항: 달마다 업데이트하며 이전달은 안 보여줌 → 월 이동 버튼 제거)
                    const Text(
                      '2026년 2월 읽기표',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    MonthGrid(
                      year: year,
                      month: month,
                      daysInMonth: daysInMonth,
                      selectedDay: _selectedDay,
                      planLabelOfDay: (d) => _planFor(d)?.label ?? '',
                      isDoneOfDay: (d) => _store.isDone(_dateKey(d)),
                      onTapDay: _onTapDay,
                    ),
                    const SizedBox(height: 16),

                    // ✅ 하단 정보창(높이 10% 줄이기: padding/버튼/패널 컴팩트)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SelectedPanel(
                                day: _selectedDay,
                                plan: plan,
                                done: _selectedDone,
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: plan == null
                                  ? null
                                  : (plan.hasVideo
                                      ? () => _onWatch(plan.videoUrl!)
                                      : _onRead),
                              child: Text(plan != null && plan.hasVideo ? '시청하기' : '읽기'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '※ 완료 체크는 읽기 완료/시청하기 클릭 시 자동 처리됩니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPanel extends StatelessWidget {
  final int day;
  final DayPlan? plan;
  final bool done;

  const _SelectedPanel({
    required this.day,
    required this.plan,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final label = plan?.label ?? '할당량 없음';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '선택 날짜: 2월 $day일',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text('할당량: $label'),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 0.9,
              child: Checkbox(value: done, onChanged: null),
            ),
            const Text('완료'),
          ],
        ),
      ],
    );
  }
}

class MonthGrid extends StatefulWidget {
  final int year;
  final int month;
  final int daysInMonth;
  final int selectedDay;

  final String Function(int day) planLabelOfDay;
  final Future<bool> Function(int day) isDoneOfDay;
  final void Function(int day) onTapDay;

  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.selectedDay,
    required this.planLabelOfDay,
    required this.isDoneOfDay,
    required this.onTapDay,
  });

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid> {
  static const week = ["일", "월", "화", "수", "목", "금", "토"];

  // 2026-02-01은 일요일(이미지 기준)
  int get startWeekdayIndex => 0;

  @override
  Widget build(BuildContext context) {
    final totalCells = startWeekdayIndex + widget.daysInMonth;
    final rows = ((totalCells + 6) ~/ 7);

    return Column(
      children: [
        Row(
          children: week.map((w) => Expanded(child: _HeaderCell(text: w))).toList(),
        ),
        const SizedBox(height: 6),
        ...List.generate(rows, (r) {
          return Row(
            children: List.generate(7, (c) {
              final idx = r * 7 + c;
              final day = idx - startWeekdayIndex + 1;

              if (day < 1 || day > widget.daysInMonth) {
                return const Expanded(child: SizedBox(height: 76));
              }

              final selected = widget.selectedDay == day;

              final baseLabel = widget.planLabelOfDay(day);

              final isSunday = ((day - 1) % 7 == 0);

              final label = (isSunday && baseLabel.isNotEmpty) ? '영상 시청' : baseLabel;

              return Expanded(
                child: FutureBuilder<bool>(
                  future: widget.isDoneOfDay(day),
                  builder: (context, snap) {
                    final done = snap.data ?? false;
                    return _DayCell(
                      day: day,
                      label: label,
                      selected: selected,
                      done: done,
                      onTap: () => widget.onTapDay(day),
                    );
                  },
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.brown.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final String label;
  final bool selected;
  final bool done;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.label,
    required this.selected,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(width: 2, color: Colors.brown)
        : Border.all(color: Colors.black12);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 76,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: border,
          borderRadius: BorderRadius.circular(8),
          color: done ? Colors.green.withOpacity(0.12) : Colors.white,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                '$day',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: done ? Colors.green : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
