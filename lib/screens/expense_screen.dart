// ============================================================
// screens/expense_screen.dart  –  Step 6: Record Expenses
// ============================================================
// Mirrors the Income screen pattern but for money OUT of the
// business. Includes an optional receipt/invoice number field,
// plus the same Paid / Pending / Partial Payment tracking Sales
// has: an expense can be settled across several installments,
// each one grouped under that expense and viewable individually,
// with the running balance updating automatically until the
// expense is fully paid off.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/cheque_details_fields.dart';
import 'recurring_expense_templates_screen.dart';
import 'verify_identity_sheet.dart';

class ExpenseScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const ExpenseScreen({super.key, this.onMenuTap});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String _filter = 'All Time';
  final List<String> _filterOptions = [
    'All Time', 'Today', 'This Week', 'This Month', 'This Year'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadAll();
    });
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddExpenseSheet(),
    );
  }

  List<Expense> _filteredExpenses(List<Expense> all) {
    final now = DateTime.now();
    return all.where((expense) {
      final date = DateTime.tryParse(expense.date);
      if (date == null) return true;
      switch (_filter) {
        case 'Today':
          return date.year == now.year && date.month == now.month && date.day == now.day;
        case 'This Week':
          return date.isAfter(now.subtract(const Duration(days: 7)));
        case 'This Month':
          return date.year == now.year && date.month == now.month;
        case 'This Year':
          return date.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final filtered = _filteredExpenses(provider.expenses);
    final total = filtered.fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: widget.onMenuTap,
        ),
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Recurring Expenses',
            icon: const Icon(Icons.repeat),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringExpenseTemplatesScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseSheet,
        backgroundColor: AppColors.expense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.expenseLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Expenses',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text(
                        AppFormat.currency(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _filterOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final option = _filterOptions[index];
                      final isSelected = option == _filter;
                      return ChoiceChip(
                        label: Text(option, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.expense,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (_) => setState(() => _filter = option),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('No expense records for this period.',
                              style: TextStyle(color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) => _ExpenseListTile(expense: filtered[index]),
                        ),
                ),
              ],
            ),
    );
  }
}

// Returns a colour depending on payment status — shared by the list
// tile and the detail sheet.
Color _statusColor(String status) {
  switch (status) {
    case 'Paid':
      return AppColors.income;
    case 'Pending':
      return AppColors.expense;
    default: // Partial Payment
      return AppColors.warning;
  }
}

class _ExpenseListTile extends StatelessWidget {
  final Expense expense;
  const _ExpenseListTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmedIntent = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete this entry?'),
                content: Text('Delete "${expense.description}" '
                    '(${AppFormat.currency(expense.amount)})? This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ??
            false;

        if (!confirmedIntent) return false;
        if (!context.mounted) return false;
        return await verifyIdentity(context, reason: 'delete this entry');
      },
      onDismissed: (_) => context.read<ExpenseProvider>().deleteExpense(expense.id!),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ExpenseDetailSheet(expense: expense),
        ),
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(expense.description,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      if (expense.paymentStatus != 'Paid') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(expense.paymentStatus).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            expense.paymentStatus,
                            style: TextStyle(
                                fontSize: 10, color: _statusColor(expense.paymentStatus), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(expense.category,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.expense, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(AppFormat.displayDate(expense.date),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            if (expense.receiptNo != null && expense.receiptNo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Receipt: ${expense.receiptNo}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (expense.paymentStatus != 'Paid')
                  Text(
                    'Balance: ${AppFormat.currency(expense.balance)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.expense, fontWeight: FontWeight.w600),
                  )
                else
                  Text(expense.paymentMethod,
                      style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                Text(
                  '-${AppFormat.currency(expense.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet();

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();
  final _amountPaidCtrl = TextEditingController(); // Only shown for Partial Payment

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  String _selectedStatus = 'Paid'; // Default to Paid
  bool _isSaving = false;
  final _chequeDetails = ChequeDetailsController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    _receiptCtrl.dispose();
    _amountPaidCtrl.dispose();
    _chequeDetails.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showError('Please select a category.');
      return;
    }
    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method.');
      return;
    }

    final totalAmount = double.parse(_amountCtrl.text.trim());

    // For a Partial Payment, an initial amount paid so far is required
    double startingAmountPaid = 0;
    if (_selectedStatus == 'Partial Payment') {
      final entered = double.tryParse(_amountPaidCtrl.text.trim());
      if (entered == null || entered <= 0) {
        _showError('Enter how much has been paid so far.');
        return;
      }
      if (entered >= totalAmount) {
        _showError('That covers the full amount — please choose "Paid" instead.');
        return;
      }
      startingAmountPaid = entered;
    }

    setState(() => _isSaving = true);

    final chequeMap = _chequeDetails.toMap();
    final expense = Expense(
      date:          AppFormat.dateToString(_selectedDate),
      amount:        totalAmount,
      description:   _descriptionCtrl.text.trim(),
      category:      _selectedCategory!,
      paymentMethod: _selectedPaymentMethod!,
      paymentStatus: _selectedStatus,
      amountPaid:    startingAmountPaid,
      receiptNo:     _receiptCtrl.text.trim().isEmpty ? null : _receiptCtrl.text.trim(),
      chequeAccountNumber: chequeMap['cheque_account_number'],
      chequeAccountName:   chequeMap['cheque_account_name'],
      chequeNumber:        chequeMap['cheque_number'],
      chequeImagePath:     _chequeDetails.imagePath,
      createdAt:     DateTime.now().toIso8601String(),
    );

    final success = await context.read<ExpenseProvider>().addExpense(expense);

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense recorded successfully!'), backgroundColor: AppColors.primary),
      );
    } else {
      _showError('Failed to save. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Add Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date *', border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(AppFormat.displayDate(AppFormat.dateToString(_selectedDate))),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (GHS) *', prefixText: 'GH₵ ', border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}), // keeps the Partial Payment validator range fresh
                  validator: (val) {
                    final amount = double.tryParse(val ?? '');
                    if (amount == null || amount <= 0) return 'Enter a valid amount greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description *', hintText: 'e.g., Shop rent for June',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) return 'Enter at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                  items: Expense.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method *', border: OutlineInputBorder()),
                  items: Expense.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _selectedPaymentMethod = val),
                ),
                if (_selectedPaymentMethod == 'Cheque') ...[
                  const SizedBox(height: 12),
                  ChequeDetailsFields(controller: _chequeDetails),
                ],
                const SizedBox(height: 12),

                // ── Payment status segmented control ────────────
                const Text('Payment Status *', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: Expense.paymentStatuses
                      .map((s) => ButtonSegment(value: s, label: Text(s, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  selected: {_selectedStatus},
                  onSelectionChanged: (selection) => setState(() => _selectedStatus = selection.first),
                ),

                // ── Amount paid so far (only for Partial Payment) ──
                if (_selectedStatus == 'Partial Payment') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountPaidCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid So Far *', prefixText: 'GH₵ ', border: OutlineInputBorder(),
                      helperText: 'The remaining balance can be settled later as further payments.',
                      helperMaxLines: 2,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                TextFormField(
                  controller: _receiptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Receipt / Invoice No. (optional)', border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Expense'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// _ExpenseDetailSheet  –  Detailed preview of one expense entry
// ============================================================
// Grouped payment history: every installment recorded against
// THIS expense (and only this one) is loaded and listed here,
// individually accessible by opening this expense's own sheet.
class _ExpenseDetailSheet extends StatefulWidget {
  final Expense expense;
  const _ExpenseDetailSheet({required this.expense});

  @override
  State<_ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends State<_ExpenseDetailSheet> {
  List<ExpensePayment> _payments = [];
  bool _isLoadingPayments = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final payments = await context.read<ExpenseProvider>().getPayments(widget.expense.id!);
    if (!mounted) return;
    setState(() {
      _payments = payments;
      _isLoadingPayments = false;
    });
  }

  void _openRecordPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordExpensePaymentSheet(expense: widget.expense),
    ).then((_) {
      _loadPayments();
      setState(() {});
    });
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-read the freshest copy of this expense from the provider, in
    // case a payment was just recorded and its status/balance changed.
    final expenses = context.watch<ExpenseProvider>().expenses;
    final expense = expenses.firstWhere((e) => e.id == widget.expense.id, orElse: () => widget.expense);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(expense.description,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(expense.paymentStatus).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      expense.paymentStatus,
                      style: TextStyle(
                          fontSize: 11, color: _statusColor(expense.paymentStatus), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _row('Date', AppFormat.displayDate(expense.date)),
              _row('Category', expense.category),
              _row('Payment Method', expense.paymentMethod),
              if (expense.receiptNo != null && expense.receiptNo!.isNotEmpty)
                _row('Receipt No.', expense.receiptNo!),
              if (expense.chequeNumber != null && expense.chequeNumber!.isNotEmpty)
                _row('Cheque No.', expense.chequeNumber!),
              if (expense.chequeAccountName != null && expense.chequeAccountName!.isNotEmpty)
                _row('Account Name', expense.chequeAccountName!),
              if (expense.chequeAccountNumber != null && expense.chequeAccountNumber!.isNotEmpty)
                _row('Account Number', expense.chequeAccountNumber!),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // ── Amount summary card ────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.expense.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(AppFormat.currency(expense.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Paid', style: TextStyle(color: AppColors.textMuted)),
                        Text(AppFormat.currency(expense.amountPaid),
                            style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (expense.paymentStatus != 'Paid') ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance Owed', style: TextStyle(color: AppColors.textMuted)),
                          Text(AppFormat.currency(expense.balance),
                              style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Payment history (grouped under this expense) ───
              const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (_isLoadingPayments)
                const Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else if (_payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No installment payments recorded yet.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ..._payments.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppFormat.displayDate(p.date),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(p.paymentMethod,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          Text(AppFormat.currency(p.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense)),
                        ],
                      ),
                    )),

              const SizedBox(height: 12),

              if (expense.paymentStatus != 'Paid')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _openRecordPaymentSheet,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Record Payment'),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text('Fully paid off',
                          style: TextStyle(fontSize: 12, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// _RecordExpensePaymentSheet  –  Log one installment payment
// ============================================================
class _RecordExpensePaymentSheet extends StatefulWidget {
  final Expense expense;
  const _RecordExpensePaymentSheet({required this.expense});

  @override
  State<_RecordExpensePaymentSheet> createState() => _RecordExpensePaymentSheetState();
}

class _RecordExpensePaymentSheetState extends State<_RecordExpensePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  DateTime _selectedDate = DateTime.now();
  String? _selectedPaymentMethod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the remaining balance — the common case is
    // "we just settled the rest of what we owed"
    _amountCtrl = TextEditingController(text: widget.expense.balance.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await context.read<ExpenseProvider>().recordPayment(
          expenseId: widget.expense.id!,
          amount: double.parse(_amountCtrl.text.trim()),
          date: AppFormat.dateToString(_selectedDate),
          paymentMethod: _selectedPaymentMethod!,
        );

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded!'), backgroundColor: AppColors.primary),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record payment. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Balance owed: ${AppFormat.currency(widget.expense.balance)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date *', border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(AppFormat.displayDate(AppFormat.dateToString(_selectedDate))),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Paid *', prefixText: 'GH₵ ', border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final amount = double.tryParse(val ?? '');
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  if (amount > widget.expense.balance + 0.01) return 'Cannot exceed the balance owed';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method *', border: OutlineInputBorder()),
                items: Expense.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _selectedPaymentMethod = val),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Payment'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
