// ============================================================
// screens/income_screen.dart  –  Step 5: Record Income
// ============================================================
// Lets the user add new income entries and browse/filter/delete
// past ones. Demonstrates the full "form → validate → save →
// refresh list" pattern used throughout the app.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/cheque_details_fields.dart';
import 'verify_identity_sheet.dart';

// Public entry point so other screens (Global Search) can open
// the same income detail view used here.
void showIncomeDetailSheet(BuildContext context, Income income) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IncomeDetailSheet(income: income),
  );
}

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  // Filter selection for the list below the form
  String _filter = 'All Time';
  final List<String> _filterOptions = [
    'All Time', 'Today', 'This Week', 'This Month', 'This Year'
  ];

  @override
  void initState() {
    super.initState();
    // Load all income records as soon as this screen first appears.
    // addPostFrameCallback ensures the widget tree is built first,
    // which avoids "setState called during build" errors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncomeProvider>().loadAll();
    });
  }

  // ── _openAddIncomeSheet: shows the bottom sheet form ────────
  void _openAddIncomeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // allows the sheet to be tall + scrollable
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddIncomeSheet(),
    );
  }

  // ── _filteredIncomes: apply the selected date filter ────────
  List<Income> _filteredIncomes(List<Income> all) {
    final now = DateTime.now();

    return all.where((income) {
      final date = DateTime.tryParse(income.date);
      if (date == null) return true;

      switch (_filter) {
        case 'Today':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case 'This Week':
          final weekAgo = now.subtract(const Duration(days: 7));
          return date.isAfter(weekAgo);
        case 'This Month':
          return date.year == now.year && date.month == now.month;
        case 'This Year':
          return date.year == now.year;
        default: // 'All Time'
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // context.watch rebuilds this widget whenever IncomeProvider calls notifyListeners()
    final provider = context.watch<IncomeProvider>();
    final filtered = _filteredIncomes(provider.incomes);

    // Calculate the total for the currently filtered list
    final total = filtered.fold<double>(0, (sum, i) => sum + i.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Income'),
      ),
      // Floating button opens the Add Income form
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddIncomeSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Income'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Total summary bar ───────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primaryLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Income',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      Text(
                        AppFormat.currency(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Filter chips ─────────────────────────────
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
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (_) => setState(() => _filter = option),
                      );
                    },
                  ),
                ),

                // ── Income list ──────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No income records for this period.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            return _IncomeListTile(income: filtered[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// _IncomeListTile  –  One swipe-to-delete row in the list
// ============================================================
class _IncomeListTile extends StatelessWidget {
  final Income income;
  const _IncomeListTile({required this.income});

  @override
  Widget build(BuildContext context) {
    // Dismissible enables the "swipe left to delete" gesture
    return Dismissible(
      key: ValueKey(income.id),
      direction: DismissDirection.endToStart, // swipe right-to-left only
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      // confirmDismiss shows a dialog BEFORE actually removing the item
      confirmDismiss: (_) async {
        final confirmedIntent = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete this entry?'),
                content: Text(
                  'Delete "${income.description}" '
                  '(${AppFormat.currency(income.amount)})? This cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ??
            false; // if dialog dismissed without choice, treat as "don't delete"

        if (!confirmedIntent) return false;
        if (!context.mounted) return false;

        // Extra security step: confirm PIN/password before the
        // deletion actually goes through
        return await verifyIdentity(context, reason: 'delete this entry');
      },
      // onDismissed runs AFTER confirmDismiss returns true
      onDismissed: (_) {
        context.read<IncomeProvider>().deleteIncome(income.id!);
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _IncomeDetailSheet(income: income),
        ),
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    income.description,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chip(income.category, AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        AppFormat.displayDate(income.date),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${AppFormat.currency(income.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.income,
                  ),
                ),
                Text(
                  income.paymentMethod,
                  style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  // Small coloured category chip
  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================
// _AddIncomeSheet  –  The "Add Income" bottom sheet form
// ============================================================
class _AddIncomeSheet extends StatefulWidget {
  const _AddIncomeSheet();

  @override
  State<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<_AddIncomeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  bool _isSaving = false;
  final _chequeDetails = ChequeDetailsController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    _chequeDetails.dispose();
    super.dispose();
  }

  // ── _pickDate: opens the native date picker ────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      // lastDate is today — the spec says "cannot be a future date"
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── _submit: validate and save the income entry ────────────
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

    setState(() => _isSaving = true);

    // Build the Income object from form values
    final income = Income(
      date:          AppFormat.dateToString(_selectedDate),
      amount:        double.parse(_amountCtrl.text.trim()),
      description:   _descriptionCtrl.text.trim(),
      category:      _selectedCategory!,
      paymentMethod: _selectedPaymentMethod!,
      notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      chequeAccountNumber: _chequeDetails.toMap()['cheque_account_number'],
      chequeAccountName:   _chequeDetails.toMap()['cheque_account_name'],
      chequeNumber:        _chequeDetails.toMap()['cheque_number'],
      chequeImagePath:     _chequeDetails.imagePath,
      createdAt:     DateTime.now().toIso8601String(),
    );

    // Save via the provider (this also triggers loadAll() to refresh the list)
    final success = await context.read<IncomeProvider>().addIncome(income);

    // After saving, refresh the VAT tracker — this is what fires
    // the 70%/90%/100% threshold notifications if crossed
    if (success && mounted) {
      await context.read<VatProvider>().loadTurnover();
    }

    setState(() => _isSaving = false);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context); // Close the bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Income recorded successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      _showError('Failed to save. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // DraggableScrollableSheet lets the user drag the sheet taller/shorter
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
                // Drag handle indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Income',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // ── Date picker field ─────────────────────────
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(AppFormat.displayDate(
                        AppFormat.dateToString(_selectedDate))),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Amount field ──────────────────────────────
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (GHS) *',
                    prefixText: 'GH₵ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final amount = double.tryParse(val ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Description field ─────────────────────────
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Source / Description *',
                    hintText: 'e.g., Market sales',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Enter at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Category dropdown ─────────────────────────
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: Income.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
                const SizedBox(height: 12),

                // ── Payment method dropdown ────────────────────
                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method *',
                    border: OutlineInputBorder(),
                  ),
                  items: Income.paymentMethods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPaymentMethod = val),
                ),
                if (_selectedPaymentMethod == 'Cheque') ...[
                  const SizedBox(height: 12),
                  ChequeDetailsFields(controller: _chequeDetails),
                ],
                const SizedBox(height: 12),

                // ── Notes (optional) ──────────────────────────
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Save button ────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Income'),
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
// _IncomeDetailSheet  –  Detailed preview of one income entry
// ============================================================
class _IncomeDetailSheet extends StatelessWidget {
  final Income income;
  const _IncomeDetailSheet({required this.income});

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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
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
          Text(income.description, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _row('Amount', AppFormat.currency(income.amount)),
          _row('Date', AppFormat.displayDate(income.date)),
          _row('Category', income.category),
          _row('Payment Method', income.paymentMethod),
          if (income.notes != null && income.notes!.isNotEmpty) _row('Notes', income.notes!),

          const SizedBox(height: 16),
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
  }
}
