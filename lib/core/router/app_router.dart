import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/expenses/expenses_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/purchases/purchases_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/main_shell.dart';

/// Tên đường dẫn dùng chung, tránh gõ sai chuỗi ở nhiều nơi.
class Routes {
  Routes._();

  // 5 tab chính
  static const home = '/';
  static const purchases = '/purchases';
  static const sales = '/sales';
  static const inventory = '/inventory';
  static const reports = '/reports';

  // Màn hình phụ (mở đè lên, không có thanh tab)
  static const products = '/products';
  static const expenses = '/expenses';
  static const settings = '/settings';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    routes: [
      // StatefulShellRoute giữ nguyên trạng thái từng tab khi chuyển qua lại.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          _branch(Routes.home, const HomeScreen()),
          _branch(Routes.purchases, const PurchasesScreen()),
          _branch(Routes.sales, const SalesScreen()),
          _branch(Routes.inventory, const InventoryScreen()),
          _branch(Routes.reports, const ReportsScreen()),
        ],
      ),
      _fullScreen(Routes.products, const ProductsScreen()),
      _fullScreen(Routes.expenses, const ExpensesScreen()),
      _fullScreen(Routes.settings, const SettingsScreen()),
    ],
  );
});

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
}

GoRoute _fullScreen(String path, Widget screen) {
  return GoRoute(
    path: path,
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) => screen,
  );
}
