// ============================================================
// screens/invoices_screen.dart  –  Invoices & Pro-forma Invoices
// ============================================================
// See models/models.dart's Invoice class and providers/
// invoice_provider.dart for the full rationale on how these two
// document types differ and how "Mark as Paid" / "Convert to
// Invoice" interact with the rest of the ledger.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../utils/invoice_generator.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddSheet() {
    // Which tab is showing decides the default document type — the
    // toggle inside the sheet still lets the user switch either way.
    final defaultType = _tabController.index == 1 ? 'Proforma' : 'Invoice';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInvoiceSheet(defaultDocumentType: defaultType),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoices'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Invoices'), Tab(text: 'Pro-forma')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 1 ? 'New Pro-forma' : 'New Invoice'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _InvoiceList(invoices: provider.realInvoices, emptyText: 'No invoices yet.'),
                _InvoiceList(invoices: provider.proformaInvoices, emptyText: 'No pro-forma invoices yet.'),
              ],
            ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<Invoice> invoices;
  final String emptyText;
  const _InvoiceList({required this.invoices, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: invoices.length,
      itemBuilder: (_, i) => _InvoiceListTile(invoice: invoices[i]),
    );
  }
}

class _InvoiceListTile extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceListTile({required this.invoice});

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':      return AppColors.income;
      case 'Overdue':    return AppColors.expense;
      case 'Cancelled':  return AppColors.textLight;
      case 'Converted':  return AppColors.info;
      case 'Sent':       return AppColors.warning;
      default:           return AppColors.textMuted; // Draft
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${invoice.customerName} · ${AppFormat.displayDate(invoice.date)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(AppFormat.currency(invoice.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _statusColor(invoice.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(invoice.status,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(invoice.status))),
            ),
          ],
        ),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _InvoiceDetailSheet(invoice: invoice),
        ),
      ),
    );
  }
}

// ── One line item's controllers, used only while the Add sheet is open ──
class _InvoiceLineControllers {
  final descriptionCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '1');
  final unitPriceCtrl = TextEditingController();

  double get total => (int.tryParse(quantityCtrl.text) ?? 0) * (double.tryParse(unitPriceCtrl.text) ?? 0);

  void dispose() {
    descriptionCtrl.dispose();
    quantityCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}

class _AddInvoiceSheet extends StatefulWidget {
  final String defaultDocumentType;
  const _AddInvoiceSheet({required this.defaultDocumentType});

  @override
  State<_AddInvoiceSheet> createState() => _AddInvoiceSheetState();
}

class _AddInvoiceSheetState extends State<_AddInvoiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _documentType;
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  bool _isSaving = false;

  final List<_InvoiceLineControllers> _lines = [_InvoiceLineControllers()];

  @override
  void initState() {
    super.initState();
    _documentType = widget.defaultDocumentType;
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerAddressCtrl.dispose();
    _notesCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_InvoiceLineControllers()));

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  double get _grandTotal => _lines.fold<double>(0, (sum, line) => sum + line.total);

  Future<void> _pickDate({required bool isDueDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_dueDate ?? _date) : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _date = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.every((l) => l.total <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with a quantity and price.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final invoice = Invoice(
      documentType: _documentType,
      invoiceNumber: '', // filled in by the provider
      date: AppFormat.dateToString(_date),
      dueDate: _documentType == 'Invoice' && _dueDate != null ? AppFormat.dateToString(_dueDate!) : null,
      customerName: _customerNameCtrl.text.trim(),
      customerPhone: _customerPhoneCtrl.text.trim().isEmpty ? null : _customerPhoneCtrl.text.trim(),
      customerAddress: _customerAddressCtrl.text.trim().isEmpty ? null : _customerAddressCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    final items = _lines
        .where((l) => l.total > 0)
        .map((l) => InvoiceItem(
              description: l.descriptionCtrl.text.trim(),
              quantity: int.tryParse(l.quantityCtrl.text) ?? 1,
              unitPrice: double.tryParse(l.unitPriceCtrl.text) ?? 0,
              lineTotal: l.total,
            ))
        .toList();

    final success = await context.read<InvoiceProvider>().addInvoice(invoice, items);

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_documentType == 'Proforma' ? 'Pro-forma' : 'Invoice'} saved successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong saving this — please try again.')),
      );
    }
  }

  Widget _buildLineItem(int index) {
    final line = _lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Item ${index + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              ),
              Text(AppFormat.currency(line.total),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              if (_lines.length > 1)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 18, color: AppColors.expense),
                  onPressed: () => _removeLine(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: line.descriptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Item / Service *', border: OutlineInputBorder(), isDense: true,
            ),
            validator: (val) => (val == null || val.trim().length < 2) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.quantityCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Qty *', border: OutlineInputBorder(), isDense: true),
                  validator: (val) => (int.tryParse(val ?? '') ?? 0) <= 0 ? '>0' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.unitPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Unit Price *', prefixText: 'GH₵', border: OutlineInputBorder(), isDense: true),
                  validator: (val) => (double.tryParse(val ?? '') ?? 0) <= 0 ? '>0' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('New ${_documentType == 'Proforma' ? 'Pro-forma Invoice' : 'Invoice'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'A Pro-forma is a quote — it never affects your ledger. An Invoice bills a customer and stays as a separate record until you mark it Paid.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Invoice', label: Text('Invoice')),
                    ButtonSegment(value: 'Proforma', label: Text('Pro-forma')),
                  ],
                  selected: {_documentType},
                  onSelectionChanged: (sel) => setState(() => _documentType = sel.first),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _customerNameCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder()),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Customer Phone (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerAddressCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Address (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('Date: ${AppFormat.displayDate(AppFormat.dateToString(_date))}'),
                        onPressed: () => _pickDate(isDueDate: false),
                      ),
                    ),
                    if (_documentType == 'Invoice') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(_dueDate == null ? 'Due date' : AppFormat.displayDate(AppFormat.dateToString(_dueDate!))),
                          onPressed: () => _pickDate(isDueDate: true),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (int i = 0; i < _lines.length; i++) _buildLineItem(i),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Another Item'),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes / Terms (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(AppFormat.currency(_grandTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InvoiceDetailSheet extends StatefulWidget {
  final Invoice invoice;
  const _InvoiceDetailSheet({required this.invoice});

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet> {
  List<InvoiceItem>? _items;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await context.read<InvoiceProvider>().getItems(widget.invoice.id!);
    if (mounted) setState(() => _items = items);
  }

  Future<void> _markAsPaid() async {
    String paymentMethod = Income.paymentMethods.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Mark as Paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This creates a matching Sale and Income entry for today, using the amount on this invoice.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: Income.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setDialogState(() => paymentMethod = val ?? paymentMethod),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    final success = await context.read<InvoiceProvider>().markAsPaid(
          invoiceId: widget.invoice.id!,
          paymentMethod: paymentMethod,
          paymentDate: AppFormat.dateToString(DateTime.now()),
        );
    setState(() => _isBusy = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as Paid — Sale and Income entries created.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong — please try again.')),
      );
    }
  }

  Future<void> _convertToInvoice() async {
    setState(() => _isBusy = true);
    final newId = await context.read<InvoiceProvider>().convertToInvoice(widget.invoice.id!);
    setState(() => _isBusy = false);
    if (!mounted) return;

    if (newId != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Converted to a real Invoice — find it under the Invoices tab.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong — please try again.')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this document?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await context.read<InvoiceProvider>().deleteInvoice(widget.invoice.id!);
    if (!mounted) return;
    if (success) Navigator.pop(context);
  }

  Future<void> _share() async {
    if (_items == null) return;
    final profile = context.read<ProfileProvider>().profile;
    setState(() => _isBusy = true);
    await shareInvoicePdf(widget.invoice, _items!, profile: profile);
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(invoice.status, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text('${invoice.customerName}${invoice.customerPhone != null ? " · ${invoice.customerPhone}" : ""}'),
              Text('Date: ${AppFormat.displayDate(invoice.date)}'
                  '${invoice.dueDate != null ? "   Due: ${AppFormat.displayDate(invoice.dueDate!)}" : ""}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const Divider(height: 24),

              if (_items == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                for (final item in _items!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${item.description} × ${item.quantity}')),
                        Text(AppFormat.currency(item.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(AppFormat.currency(invoice.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],

              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(invoice.notes!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],

              const SizedBox(height: 20),
              if (_isBusy) const Center(child: CircularProgressIndicator()) else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _items == null ? null : _share,
                    icon: const Icon(Icons.share),
                    label: const Text('Share PDF'),
                  ),
                ),
                const SizedBox(height: 8),
                if (invoice.documentType == 'Invoice' && invoice.status != 'Paid' && invoice.status != 'Cancelled')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.income),
                      onPressed: _markAsPaid,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Mark as Paid', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                if (invoice.isProforma && invoice.status != 'Converted' && invoice.status != 'Cancelled') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                      onPressed: _convertToInvoice,
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      label: const Text('Convert to Invoice', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.expense),
                    label: const Text('Delete', style: TextStyle(color: AppColors.expense)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
