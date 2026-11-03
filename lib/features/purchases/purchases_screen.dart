import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thu mua')),
      body: const ComingSoon(
        icon: Icons.shopping_basket_outlined,
        message: 'Phiếu thu mua sẽ có ở Giai đoạn 3',
      ),
    );
  }
}
