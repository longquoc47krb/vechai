import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi phí')),
      body: const ComingSoon(
        icon: Icons.receipt_long_outlined,
        message: 'Quản lý chi phí sẽ có ở Giai đoạn 5',
      ),
    );
  }
}
