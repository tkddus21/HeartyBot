//guardian_medication_screen.dart
import 'package:flutter/material.dart';

class GuardianMedicationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF6F5FC),
      child: ListView(
        children: [
          ListTile(
            title: Text("2025-07-28", style: TextStyle(color: Color(0xFF333333))),
            subtitle: Text("아침약: ✅ / 저녁약: ✅", style: TextStyle(color: Color(0xFF333333))),
          ),
          ListTile(
            title: Text("2025-07-27", style: TextStyle(color: Color(0xFF333333))),
            subtitle: Text("아침약: ✅ / 저녁약: ❌", style: TextStyle(color: Color(0xFF333333))),
          ),
        ],
      ),
    );
  }
}
