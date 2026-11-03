import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/formatters.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(GĐ6): thay số 0 bằng số liệu thật từ ReportRepository.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ve Chai Manager'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (path) => context.push(path),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: Routes.products,
                child: ListTile(
                  leading: Icon(Icons.category_outlined),
                  title: Text('Mặt hàng'),
                ),
              ),
              PopupMenuItem(
                value: Routes.expenses,
                child: ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Chi phí'),
                ),
              ),
              PopupMenuItem(
                value: Routes.settings,
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Cài đặt'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hôm nay, ${formatDate(DateTime.now())}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const _StatGrid(
            children: [
              _StatCard(label: 'Tiền thu mua', value: 0, icon: Icons.south_west),
              _StatCard(label: 'Tiền bán', value: 0, icon: Icons.north_east),
            ],
          ),
          const SizedBox(height: 12),
          const _StatCard(
            label: 'Lợi nhuận hôm nay',
            value: 0,
            icon: Icons.savings_outlined,
            highlight: true,
          ),
          const SizedBox(height: 12),
          const _StatGrid(
            children: [
              _CountCard(label: 'Phiếu thu mua', count: 0),
              _CountCard(label: 'Phiếu bán', count: 0),
            ],
          ),
          const SizedBox(height: 12),
          const _SyncStatusCard(),
          const SizedBox(height: 24),
          Text('Lối tắt', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const _StatGrid(
            children: [
              _Shortcut(
                label: 'Thu mua',
                icon: Icons.shopping_basket,
                path: Routes.purchases,
              ),
              _Shortcut(
                label: 'Bán hàng',
                icon: Icons.point_of_sale,
                path: Routes.sales,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _StatGrid(
            children: [
              _Shortcut(
                label: 'Kho hàng',
                icon: Icons.inventory_2,
                path: Routes.inventory,
              ),
              _Shortcut(
                label: 'Báo cáo',
                icon: Icons.bar_chart,
                path: Routes.reports,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Xếp 2 ô cạnh nhau, chiều cao bằng nhau.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 12),
          Expanded(child: children[1]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlight ? scheme.onPrimary : scheme.onSurface;
    return Card(
      color: highlight ? scheme.primary : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: highlight ? fg : scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: TextStyle(color: fg))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatVnd(value),
              style: TextStyle(
                fontSize: highlight ? 26 : 20,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard();

  @override
  Widget build(BuildContext context) {
    // TODO(GĐ8): hiển thị trạng thái thật: Đã đồng bộ / Chờ / Thất bại.
    return const Card(
      child: ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Đồng bộ Google Sheets'),
        subtitle: Text('Chưa cấu hình'),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.label, required this.icon, required this.path});

  final String label;
  final IconData icon;
  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // go() với đường dẫn của tab sẽ chuyển sang tab đó.
        onTap: () => context.go(path),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 36, color: scheme.onPrimaryContainer),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
