import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/inventory_repository.dart';
import '../../domain/inventory.dart';

final inventoryProvider =
    FutureProvider.family<List<InventoryRow>, InventoryPeriod>((ref, period) {
      final (from, to) = period.range(DateTime.now());
      return ref
          .watch(inventoryRepositoryProvider)
          .summary(from: from, to: to);
    });

final productHistoryProvider =
    FutureProvider.family<List<ProductPurchaseEntry>, String>(
      (ref, productId) =>
          ref.watch(inventoryRepositoryProvider).history(productId),
    );
