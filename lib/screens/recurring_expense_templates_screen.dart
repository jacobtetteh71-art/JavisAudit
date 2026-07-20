// ============================================================
// screens/recurring_expense_templates_screen.dart
// ============================================================
// Rent, salaries, utilities — the same expense every month.
// Save it once as a template, then log it again with one tap
// instead of retyping the description/category/amount each time.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

class RecurringExpenseTemplatesScreen extends StatefulWidget {
  const RecurringExpenseTemplatesScreen({super.key});

  @override
  State<RecurringExpenseTemplatesScreen> createState() => _RecurringExpenseTemplatesScreenState();
}

class _RecurringExpenseTemplatesScreenState extends State<RecurringExpenseTemplatesScreen> {
  List<RecurringExpenseTemplate> _templates = [];
  bool _isLoading = true;
  int? _loggingId; // template currently being logged, for a small spinner

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final rows = await DatabaseHelper.instance.getRecurringExpenseTemplates();
    if (!mounted) return;
    setState(() {
      _templates = rows.map((r) => RecurringExpenseTemplate.fromMap(r)).toList();
      _isLoading = false;
    });
  }

  void _openAddTemplateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddTemplateSheet(),
    ).then((_) => _load());
  }

  // ── _logNow: the whole point of this screen — one tap logs an
  // expense today, with the template's saved values, marked Paid.
  Future<void> _logNow(RecurringExpenseTemplate template) async {
    setState(() => _loggingId = template.id);
    final expense = Expense(
      date:          AppFormat.today(),
      amount:        template.amount,
      description:   template.description,
      category:      template.category,
      paymentMethod: template.paymentMethod,
      paymentStatus: 'Paid',
      amountPaid:    template.amount,
      createdAt:     DateTime.now().toIso8601String(),
    );
    final success = await context.read<ExpenseProvider>().addExpense(expense);
    if (!mounted) return;
    setState(() => _loggingId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '${template.description} logged for today (${AppFormat.currency(template.amount)})'
            : 'Failed to log expense. Please try again.'),
        backgroundColor: success ? AppColors.primary : Colors.red,
      ),
    );
  }

  Future<void> _deleteTemplate(RecurringExpenseTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove template?'),
        content: Text('Remove "${template.description}"? This only deletes the template — '
            'any expenses already logged from it stay in your records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteRecurringExpenseTemplate(template.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Recurring Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTemplateSheet,
        backgroundColor: AppColors.expense,
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 100),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'No templates yet. Save your rent, salaries, or utility bill as a '
                        'template so you can log it again in one tap next month.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _templates.length,
                  itemBuilder: (_, index) {
                    final template = _templates[index];
                    final isLogging = _loggingId == template.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(template.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.expense.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(template.category,
                                          style: const TextStyle(fontSize: 10, color: AppColors.expense, fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(AppFormat.currency(template.amount),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                            onPressed: () => _deleteTemplate(template),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: isLogging ? null : () => _logNow(template),
                            icon: isLogging
                                ? const SizedBox(
                                    height: 14, width: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.bolt, size: 16),
                            label: const Text('Log Now'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================
// _AddTemplateSheet  –  Create a new recurring expense template
// ============================================================
class _AddTemplateSheet extends StatefulWidget {
  const _AddTemplateSheet();

  @override
  State<_AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends State<_AddTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category and payment method.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final template = RecurringExpenseTemplate(
      description:   _descriptionCtrl.text.trim(),
      category:      _selectedCategory!,
      amount:        double.parse(_amountCtrl.text.trim()),
      paymentMethod: _selectedPaymentMethod!,
      createdAt:     DateTime.now().toIso8601String(),
    );
    await DatabaseHelper.instance.insertRecurringExpenseTemplate(template.toMap());

    if (!mounted) return;
    Navigator.pop(context);
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
              const Text('New Recurring Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description *', hintText: 'e.g., Shop Rent, Staff Salaries',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => (val == null || val.trim().length < 3) ? 'Enter at least 3 characters' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (GHS) *', prefixText: 'GH₵ ', border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final amount = double.tryParse(val ?? '');
                  if (amount == null || amount <= 0) return 'Enter a valid amount greater than 0';
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
                decoration: const InputDecoration(labelText: 'Usual Payment Method *', border: OutlineInputBorder()),
                items: Expense.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) => setState(() => _selectedPaymentMethod = val),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Template'),
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
