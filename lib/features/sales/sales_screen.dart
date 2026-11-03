import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bán hàng')),
      body: const ComingSoon(
        icon: Icons.point_of_sale_outlined,
        message: 'Phiếu bán sẽ có ở Giai đoạn 4',
      ),
    );
  }
}
