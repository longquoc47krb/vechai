import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/day_group.dart';
import '../utils/formatters.dart';

/// Tiêu đề nhóm ngày trong danh sách phiếu: "Thứ Ba, 03/11/2026 ... 1.200.000đ".
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.group});

  final DayGroup<Object?> group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekday = DateFormat('EEEE', 'vi').format(group.day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          // Expanded + ellipsis: chữ to / màn hẹp thì cắt bớt tên thứ,
          // không bị tràn.
          Expanded(
            child: Text(
              '${weekday[0].toUpperCase()}${weekday.substring(1)}, '
              '${formatDate(group.day)}',
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatVnd(group.activeTotal),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
