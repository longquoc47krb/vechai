import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/money_field.dart';
import '../../data/repositories/sale_repository.dart';
import '../../domain/sale.dart';
import 'sales_providers.dart';

/// Màn tạo phiếu bán mới ([saleId] == null) hoặc sửa phiếu bán.
class SaleFormScreen extends ConsumerWidget {
  const SaleFormScreen({super.key, this.saleId});

  final String? saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = saleId;
    if (id == null) return const _SaleForm(sale: null);

    Widget message(String text) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(text)),
    );

    return ref
        .watch(saleDetailProvider(id))
        .when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => message(friendlyError(e)),
          data: (sale) {
            if (sale == null) return message('Không tìm thấy phiếu');
            if (sale.isCancelled) return message('Phiếu đã hủy, không sửa được');
            return _SaleForm(sale: sale);
          },
        );
  }
}

class _SaleForm extends ConsumerStatefulWidget {
  const _SaleForm({required this.sale});

  final Sale? sale;

  @override
  ConsumerState<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends ConsumerState<_SaleForm> {
  final _formKey = GlobalKey<FormState>();

  /// UUID cấp sẵn -> bấm Lưu nhiều lần vẫn chỉ ra 1 phiếu.
  late final String _id;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _buyer;
  late final TextEditingController _note;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.sale != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sale;
    _id = s?.id ?? const Uuid().v4();
    _date = s?.saleDate ?? DateTime.now();
    _amount = TextEditingController(
      text: s == null ? '' : formatMoneyInput(s.totalAmount),
    );
    _buyer = TextEditingController(text: s?.buyerName ?? '');
    _note = TextEditingController(text: s?.note ?? '');
    for (final c in [_amount, _buyer, _note]) {
      c.addListener(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _buyer.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final input = SaleInput(
      saleDate: _date,
      totalAmount: parseMoney(_amount.text) ?? 0,
      buyerName: _buyer.text,
      note: _note.text,
    );

    try {
      final repo = ref.read(saleRepositoryProvider);
      final saved = _isEdit
          ? await repo.update(_id, input)
          : await repo.create(_id, input);
      refreshSaleData(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu phiếu ${saved.code}: ${formatVnd(saved.totalAmount)}',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Bỏ thay đổi?',
      message: 'Phiếu bán chưa được lưu. Thoát sẽ mất thông tin vừa nhập.',
      confirmLabel: 'Thoát',
      cancelLabel: 'Ở lại',
      destructive: true,
    );
    if (leave && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Sửa ${widget.sale!.code}' : 'Phiếu bán mới'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Ngày bán'),
                  subtitle: Text(
                    formatDateTime(_date),
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 16),
              _BigMoneyField(controller: _amount, autofocus: !_isEdit),
              const SizedBox(height: 16),
              TextFormField(
                controller: _buyer,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Người mua (không bắt buộc)',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  prefixIcon: Icon(Icons.notes),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chỉ ghi tổng tiền bán, không cần nhập từng mặt hàng.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Đang lưu...' : 'Lưu phiếu bán'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô nhập tổng tiền cỡ lớn, là thông tin chính của phiếu bán.
class _BigMoneyField extends StatelessWidget {
  const _BigMoneyField({required this.controller, required this.autofocus});

  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [MoneyInputFormatter()],
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: scheme.primary,
      ),
      decoration: const InputDecoration(
        labelText: 'Tổng tiền bán *',
        suffixText: 'đ',
        prefixIcon: Icon(Icons.payments_outlined),
      ),
      validator: (v) {
        final amount = parseMoney(v ?? '') ?? 0;
        if (amount <= 0) return 'Vui lòng nhập tổng tiền bán';
        if (amount > SaleInput.maxAmount) return 'Tổng tiền quá lớn';
        return null;
      },
    );
  }
}
