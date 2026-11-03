import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mặt hàng')),
      body: const ComingSoon(
        icon: Icons.category_outlined,
        message: 'Quản lý mặt hàng sẽ có ở Giai đoạn 2',
      ),
    );
  }
}
