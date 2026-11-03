import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/expenses/expenses_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/product_history_screen.dart';
import '../../features/products/product_form_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/purchases/purchase_detail_screen.dart';
import '../../features/purchases/purchase_form_screen.dart';
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
  static const purchaseNew = '/purchases/new';
  static String purchaseDetail(String id) => '/purchases/$id';
  static String purchaseEdit(String id) => '/purchases/$id/edit';
  static String productHistory(String productId) => '/inventory/$productId';

  static const products = '/products';
  static const productNew = '/products/new';
  static String productEdit(String id) => '/products/$id';
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
          _branch(Routes.home, (_) => const HomeScreen()),
          _branch(
            Routes.purchases,
            (_) => const PurchasesScreen(),
            // 'new' khai báo trước ':id' để không bị hiểu nhầm là id = "new".
            [
              _page('new', (_) => const PurchaseFormScreen()),
              _page(
                ':id',
                (s) => PurchaseDetailScreen(purchaseId: s.pathParameters['id']!),
                [
                  _page(
                    'edit',
                    (s) =>
                        PurchaseFormScreen(purchaseId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          _branch(Routes.sales, (_) => const SalesScreen()),
          _branch(Routes.inventory, (_) => const InventoryScreen(), [
            _page(
              ':productId',
              (s) => ProductHistoryScreen(
                productId: s.pathParameters['productId']!,
                productName: s.extra as String?,
              ),
            ),
          ]),
          _branch(Routes.reports, (_) => const ReportsScreen()),
        ],
      ),
      _page(Routes.products, (_) => const ProductsScreen(), [
        _page('new', (_) => const ProductFormScreen()),
        _page(
          ':id',
          (s) => ProductFormScreen(productId: s.pathParameters['id']),
        ),
      ]),
      _page(Routes.expenses, (_) => const ExpensesScreen()),
      _page(Routes.settings, (_) => const SettingsScreen()),
    ],
  );
});

typedef _Builder = Widget Function(GoRouterState state);

/// Màn gốc của một tab.
StatefulShellBranch _branch(
  String path,
  _Builder builder, [
  List<RouteBase> routes = const [],
]) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => builder(state),
        routes: routes,
      ),
    ],
  );
}

/// Màn phụ: mở trên navigator gốc nên che luôn thanh tab.
GoRoute _page(
  String path,
  _Builder builder, [
  List<RouteBase> routes = const [],
]) {
  return GoRoute(
    path: path,
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) => builder(state),
    routes: routes,
  );
}
