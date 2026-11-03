import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kho hàng')),
      body: const ComingSoon(
        icon: Icons.inventory_2_outlined,
        message: 'Thống kê hàng đã thu mua sẽ có ở Giai đoạn 3',
      ),
    );
  }
}
