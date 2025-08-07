import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedRange = '오늘';

  final Map<String, int> emotionSummary = {
    '😊': 5,
    '😢': 2,
    '😡': 1,
  };

  List<FlSpot> emotionTrend = [
    FlSpot(1, 3), // day 1 → score 3
    FlSpot(2, 4),
    FlSpot(3, 2),
    FlSpot(4, 3),
    FlSpot(5, 5),
  ];

  void _shareReport() {
    Share.share('오늘의 감정 상태: 😊 기쁨\n주간 평균: 😊 5회, 😢 2회, 😡 1회');
  }

  void _changeRange(String? value) {
    if (value != null) {
      setState(() {
        _selectedRange = value;
      });
      // TODO: 데이터 변경 로직 구현
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("감정 리포트"),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareReport,
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [

            // 날짜 범위 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("기간: "),
                DropdownButton<String>(
                  value: _selectedRange,
                  items: ['오늘', '주간', '월간'].map((label) {
                    return DropdownMenuItem(
                      child: Text(label),
                      value: label,
                    );
                  }).toList(),
                  onChanged: _changeRange,
                ),
              ],
            ),
            SizedBox(height: 16),

            // 감정 이모지 통계
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emotionSummary.entries.map((entry) {
                return Column(
                  children: [
                    Text(entry.key, style: TextStyle(fontSize: 32)),
                    SizedBox(height: 4),
                    Text('${entry.value}회', style: TextStyle(fontSize: 16)),
                  ],
                );
              }).toList(),
            ),
            SizedBox(height: 32),

            // 감정 추이 차트
            AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: emotionTrend,
                      isCurved: true,
                      color: Colors.purple,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // 상세보기 버튼
            ElevatedButton.icon(
              onPressed: () {
                // TODO: 상세페이지 연결
              },
              icon: Icon(Icons.search),
              label: Text("상세 보기"),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
