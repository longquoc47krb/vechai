import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: const ComingSoon(
        icon: Icons.bar_chart_outlined,
        message: 'Báo cáo tuần / tháng / năm sẽ có ở Giai đoạn 6',
      ),
    );
  }
}
