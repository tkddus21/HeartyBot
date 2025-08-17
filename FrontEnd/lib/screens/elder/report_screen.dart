import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedRange = '오늘';

  // UI 표시용 집계
  Map<String, int> _emotionSummary = {'😊': 0, '😢': 0, '😐': 0};
  List<FlSpot> _emotionTrend = [];
  bool _loading = true;
  String? _error;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // 감정 매핑
  static const Map<String, String> _emotionToEmoji = {
    '기쁨': '😊',
    '슬픔': '😢',
    '중립': '😐',
  };

  static const Map<String, int> _emotionToScore = {
    '기쁨': 2,
    '중립': 1,
    '슬픔': 0,
  };

  @override
  void initState() {
    super.initState();
    _attachListenerForRange(_selectedRange);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _changeRange(String? value) {
    if (value == null) return;
    setState(() {
      _selectedRange = value;
      _loading = true;
      _error = null;
      _emotionSummary = {'😊': 0, '😢': 0, '😐': 0};
      _emotionTrend = [];
    });
    _attachListenerForRange(value);
  }

  /// 선택된 기간의 [시작, 끝) 범위 계산 (끝은 now)
  List<DateTime> _dateRangeFor(String range) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (range == '오늘') {
      return [todayStart, todayStart.add(const Duration(days: 1))];
    } else if (range == '주간') {
      final start = todayStart.subtract(const Duration(days: 6)); // 최근 7일
      return [start, todayStart.add(const Duration(days: 1))];
    } else {
      final start = todayStart.subtract(const Duration(days: 29)); // 최근 30일
      return [start, todayStart.add(const Duration(days: 1))];
    }
  }

  Future<User> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    var user = auth.currentUser;
    if (user == null) {
      final cred = await auth.signInAnonymously();
      user = cred.user!;
    }
    return user!;
  }

  void _attachListenerForRange(String range) async {
    _sub?.cancel();

    try {
      final user = await _ensureAuth();
      final uid = user.uid;
      final dates = _dateRangeFor(range);
      final start = dates[0];
      final end = dates[1];

      final query = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('diaries')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt'); // 범위 필터와 함께 정렬 필수

      _sub = query.snapshots().listen((snap) {
        _computeStats(range, snap.docs);
      }, onError: (e) {
        setState(() {
          _loading = false;
          _error = '데이터를 불러오는 중 오류가 발생했습니다: $e';
        });
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '초기화 실패: $e';
      });
    }
  }

  void _computeStats(String range, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // 1) 감정 카운트
    final Map<String, int> counts = {'😊': 0, '😢': 0, '😐': 0};

    // 2) 추이 계산용 버퍼
    final List<_Entry> entries = [];
    for (final d in docs) {
      final data = d.data();
      final emotion = (data['emotion'] ?? '중립').toString();
      final ts = data[''];
      if (ts == null || ts is! Timestamp) continue;
      final dt = ts.toDate();

      final emoji = _emotionToEmoji[emotion] ?? '😐';
      counts[emoji] = (counts[emoji] ?? 0) + 1;

      final score = _emotionToScore[emotion] ?? 1;
      entries.add(_Entry(dt: dt, score: score));
    }

    // 3) 추이(오늘: 시퀀스 / 주간·월간: 일자별 평균)
    List<FlSpot> trend = [];
    if (entries.isEmpty) {
      trend = [];
    } else if (range == '오늘') {
      // 입력 순서대로
      entries.sort((a, b) => a.dt.compareTo(b.dt));
      for (int i = 0; i < entries.length; i++) {
        trend.add(FlSpot((i + 1).toDouble(), entries[i].score.toDouble()));
      }
    } else {
      // 일자별 평균
      final Map<DateTime, List<int>> byDay = {};
      for (final e in entries) {
        final key = DateTime(e.dt.year, e.dt.month, e.dt.day);
        byDay.putIfAbsent(key, () => []).add(e.score);
      }
      final days = byDay.keys.toList()..sort();
      double x = 1;
      for (final day in days) {
        final vals = byDay[day]!;
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        trend.add(FlSpot(x, avg));
        x += 1;
      }
    }

    setState(() {
      _emotionSummary = counts;
      _emotionTrend = trend;
      _loading = false;
      _error = null;
    });
  }

  void _shareReport() {
    final total = _emotionSummary.values.fold<int>(0, (a, b) => a + b);
    final msg = StringBuffer()
      ..writeln('감정 리포트 (${_selectedRange})')
      ..writeln('총 ${total}회 기록')
      ..writeln('😊 기쁨: ${_emotionSummary['😊']}회')
      ..writeln('😢 슬픔: ${_emotionSummary['😢']}회')
      ..writeln('😐 중립: ${_emotionSummary['😐']}회');
    Share.share(msg.toString());
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
        : _buildReportBody();

    return Scaffold(
      appBar: AppBar(
        title: const Text("감정 리포트"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 날짜 범위 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("기간: "),
                DropdownButton<String>(
                  value: _selectedRange,
                  items: ['오늘', '주간', '월간'].map((label) {
                    return DropdownMenuItem(
                      value: label,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: _changeRange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildReportBody() {
    final hasAny = _emotionSummary.values.any((v) => v > 0);
    if (!hasAny) {
      return const Center(child: Text('선택한 기간에 데이터가 없습니다.'));
    }

    return Column(
      children: [
        // 감정 이모지 통계
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _emotionSummary.entries.map((entry) {
            return Column(
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 4),
                Text('${entry.value}회', style: const TextStyle(fontSize: 16)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        // 감정 추이 차트
        AspectRatio(
          aspectRatio: 1.5,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 2, // 슬픔0~기쁨2
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, meta) {
                      // 0=슬픔, 1=중립, 2=기쁨
                      final label = (v.round() == 0)
                          ? '슬픔'
                          : (v.round() == 1)
                          ? '중립'
                          : (v.round() == 2)
                          ? '기쁨'
                          : '';
                      return Text(label, style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _emotionTrend,
                  isCurved: true,
                  color: Colors.purple,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 상세보기 버튼 (필요 시 연결)
        ElevatedButton.icon(
          onPressed: () {
            // TODO: 상세페이지 연결
          },
          icon: const Icon(Icons.search),
          label: const Text("상세 보기"),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
      ],
    );
  }
}

class _Entry {
  final DateTime dt;
  final int score;
  _Entry({required this.dt, required this.score});
}
