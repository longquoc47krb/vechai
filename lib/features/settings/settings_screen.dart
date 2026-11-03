import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: const ComingSoon(
        icon: Icons.settings_outlined,
        message: 'Kết nối Google Sheets sẽ có ở Giai đoạn 7',
      ),
    );
  }
}
