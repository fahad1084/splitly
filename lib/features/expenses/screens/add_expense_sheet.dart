import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:splitly/features/auth/controllers/auth_controller.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../groups/models/group_model.dart';
import '../../balances/controllers/balances_controller.dart';
import '../controllers/expenses_controller.dart';
import '../models/expense_model.dart';
import 'receipt_scanner_screen.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/utils/money_format.dart';

// With [expense]: edit that expense instead of adding a new one.
void showAddExpenseSheet(BuildContext context, GroupModel group,
    {ExpenseModel? expense}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddExpenseSheet(group: group, expense: expense),
  );
}

// ── Category icon data (Flutter icons instead of emojis) ─────────────────────
const _categoryIcons = [
  {'id': 'food',          'label': 'Food',       'icon': Icons.restaurant_rounded},
  {'id': 'ration',        'label': 'Ration',     'icon': Icons.shopping_cart_rounded},
  {'id': 'utilities',     'label': 'Utilities',  'icon': Icons.bolt_rounded},
  {'id': 'transport',     'label': 'Transport',  'icon': Icons.directions_car_rounded},
  {'id': 'rent',          'label': 'Rent',       'icon': Icons.home_rounded},
  {'id': 'entertainment', 'label': 'Fun',        'icon': Icons.sports_esports_rounded},
  {'id': 'medicine',      'label': 'Medicine',   'icon': Icons.medical_services_rounded},
  {'id': 'travel',        'label': 'Travel',     'icon': Icons.flight_rounded},
  {'id': 'other',         'label': 'Other',      'icon': Icons.category_rounded},
];

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final GroupModel group;
  final ExpenseModel? expense; // null = add a new expense
  const _AddExpenseSheet({required this.group, this.expense});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = 'food';
  String _splitType = 'equal';
  String? _paidBy;
  bool _isLoading = false;
  bool _isRecurring = false;
  String _recurEvery = 'monthly'; // daily | weekly | monthly
  DateTime _expenseDate = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<Map<String, dynamic>> _members = [];
  // Editing: someone in this expense's split has left the group, so the
  // split can't be saved again (the server would refuse it too)
  bool _someoneLeft = false;

  late TabController _splitTabCtrl;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _notesCtrl.text = e.notes ?? '';
      _category = e.category;
      _splitType = e.splitType;
      _expenseDate = e.expenseDate;
    }
    _splitTabCtrl = TabController(
        length: 3,
        vsync: this,
        initialIndex: ['equal', 'custom', 'percentage']
            .indexOf(_splitType)
            .clamp(0, 2));
    _splitTabCtrl.addListener(() {
      if (!_splitTabCtrl.indexIsChanging) {
        setState(() {
          _splitType =
          ['equal', 'custom', 'percentage'][_splitTabCtrl.index];
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load members here instead of initState
    // didChangeDependencies is called after providers are ready
    _loadMembers();
  }

  void _loadMembers() {
    // Read members synchronously from the provider cache
    ref.read(groupMembersProvider(widget.group.id)).whenData((members) {
      if (_members.isNotEmpty || members.isEmpty) return; // already loaded
      if (mounted) setState(() => _setMembers(members));
    });
  }

  // Group members -> split rows. Adding: everyone included, I paid.
  // Editing: the expense's own split and payer.
  void _setMembers(List<Map<String, dynamic>> members) {
    final e = widget.expense;
    final splitOf = {
      for (final s in e?.splits ?? const <ExpenseSplit>[]) s.userId: s
    };
    _members = members.map((m) {
      final profile = m['profiles'] as Map<String, dynamic>? ?? {};
      final userId = profile['id'] as String? ?? '';
      final split = splitOf[userId];
      return <String, dynamic>{
        'user_id': userId,
        'name': profile['full_name'] as String? ?? 'Unknown',
        'avatar_color': profile['avatar_color'] as String? ?? '#0F766E',
        'avatar_url': profile['avatar_url'] as String?,
        'included': e == null || split != null,
        'custom_amount': split?.amountOwed ?? 0.0,
        'percentage': split != null && e!.amount > 0
            ? (split.amountOwed * 10000 / e.amount).round() / 100
            : 0.0,
      };
    }).toList();
    _paidBy = e?.paidBy ?? ref.read(currentUserProvider)?.id ?? '';
    _someoneLeft = e != null &&
        splitOf.keys.any((id) => !_members.any((m) => m['user_id'] == id));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _splitTabCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (_titleCtrl.text.trim().isEmpty) {
      showErrorSnack(context, l10n.pleaseEnterTitle);
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      showErrorSnack(context, l10n.pleaseEnterValidAmount);
      return;
    }
    if (_members.isEmpty) {
      showErrorSnack(context, l10n.noMembersToSplit);
      return;
    }
    if (_paidBy == null) {
      showErrorSnack(context, l10n.pleaseSelectWhoPaid);
      return;
    }
    if (_someoneLeft) {
      showErrorSnack(context, l10n.cantEditMemberLeft);
      return;
    }

    // At least one person must be in the split (the server checks too)
    if (!_members.any((m) => m['included'] as bool)) {
      showErrorSnack(context, l10n.noMembersToSplit);
      return;
    }

    if (_splitType == 'custom') {
      // Compare in whole paisa — the server requires an EXACT match
      final totalPaisa = _members
          .where((m) => m['included'] as bool)
          .fold<int>(0, (sum, m) => sum + toPaisa(m['custom_amount'] as double));
      if (totalPaisa != toPaisa(amount)) {
        showErrorSnack(context,
            l10n.customAmountsMustAddUp(
                widget.group.currency, formatAmount(amount)));
        return;
      }
    }

    if (_splitType == 'percentage') {
      // 33.33 / 33.33 / 33.33 is accepted (see percentagesAddUp)
      final percentages = _members
          .where((m) => m['included'] as bool)
          .map((m) => m['percentage'] as double)
          .toList();
      if (!percentagesAddUp(percentages)) {
        showErrorSnack(context, l10n.percentagesMustAddTo100);
        return;
      }
    }

    if (_editing && !await _confirmEditWithPayments()) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    final notifier = ref.read(expensesProvider(widget.group.id).notifier);
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    final error = _editing
        ? await notifier.editExpense(
            expenseId: widget.expense!.id,
            title: _titleCtrl.text.trim(),
            amount: amount,
            category: _category,
            splitType: _splitType,
            members: _members,
            expenseDate: _expenseDate,
            notes: notes,
          )
        : await notifier.addExpense(
      title: _titleCtrl.text.trim(),
      amount: amount,
      category: _category,
      paidBy: _paidBy!,
      splitType: _splitType,
      members: _members,
      currency: widget.group.currency,
      expenseDate: _expenseDate,
      notes: notes,
      isRecurring: _isRecurring,
      recurEvery: _isRecurring ? _recurEvery : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      // Server error codes → existing translated messages
      final message = switch (error) {
        'NO_MEMBERS' => l10n.noMembersToSplit,
        'INVALID_AMOUNT' => l10n.pleaseEnterValidAmount,
        'INVALID_TITLE' => l10n.pleaseEnterTitle,
        'SPLITS_DONT_ADD_UP' || 'INVALID_SPLIT_AMOUNT' =>
            l10n.customAmountsMustAddUp(
                widget.group.currency, formatAmount(amount)),
        'SPLIT_USER_NOT_MEMBER' || 'PAYER_NOT_MEMBER' => l10n.cantEditMemberLeft,
        'NOT_ALLOWED' => l10n.onlyPayerOrAdminCanEdit,
        _ => l10n.somethingWentWrong,
      };
      showErrorSnack(context, message);
    } else {
      showSuccessSnack(
          context, _editing ? l10n.expenseUpdated : l10n.expenseAdded);
      Navigator.pop(context);
    }
  }

  // Payments already made after this expense between its people? Changing
  // it changes balances they paid against (same check as delete, Phase 1).
  Future<bool> _confirmEditWithPayments() async {
    final l10n = AppLocalizations.of(context)!;
    var warn = false;
    try {
      final payments =
          await ref.read(settlementsProvider(widget.group.id).future);
      warn = hasPaymentsAfterExpense(widget.expense!, payments);
    } catch (_) {
      warn = false; // can't check (offline?) - the save itself still works
    }
    if (!warn || !mounted) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editExpense),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.accentDark, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.expenseEditHasPaymentsWarning,
                  style: TextStyle(
                      color: AppColors.warningText(context),
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // Pre-filled custom amount / percentage: '' when 0, no needless '.00'
  String _initialField(Object? value) {
    final v = (value as num?)?.toDouble() ?? 0;
    if (v == 0) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: _today(), // no future dates (the server checks too)
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  String _dateText(AppLocalizations l10n) {
    final today = _today();
    if (_expenseDate == today) return l10n.todayLabel;
    if (_expenseDate == today.subtract(const Duration(days: 1))) {
      return l10n.yesterdayLabel;
    }
    return DateFormat.yMMMd(l10n.localeName).format(_expenseDate);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? const Color(0xFF042F2E) : Colors.white;
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final subBg = dark ? AppColors.primaryDark : AppColors.primaryTint;

    // Watch the members so the sheet fills in when they finish loading
    ref.watch(groupMembersProvider(widget.group.id)).whenData((members) {
      if (_members.isEmpty && members.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _members.isEmpty) setState(() => _setMembers(members));
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Drag handle ───────────────────────────────────────────
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(_editing ? l10n.editExpense : l10n.addExpense,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: headingColor,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(widget.group.name,
                style:
                const TextStyle(fontSize: 13, color: AppColors.primary)),

            const SizedBox(height: 24),

            // ── Title ─────────────────────────────────────────────────
            SplitlyTextField(
              controller: _titleCtrl,
              label: l10n.whatWasItForHint,
              hint: l10n.expenseTitleHint,
              prefixIcon: Icons.receipt_outlined,
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_editing,
            ),

            const SizedBox(height: 14),

            // ── Amount ────────────────────────────────────────────────
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}), // rebuild for equal split
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary),
              decoration: InputDecoration(
                labelText: l10n.amount,
                labelStyle: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    fontSize: 15),
                floatingLabelStyle: const TextStyle(
                    color: AppColors.primary, fontSize: 13),
                hintText: '0.00',
                hintStyle: TextStyle(
                    color: AppColors.primaryLight.withValues(alpha: 0.4),
                    fontSize: 28),
                prefixIcon: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Text(widget.group.currency,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary)),
                ),
                prefixIconConstraints: const BoxConstraints(),
                // Receipt scan button
                suffixIcon: IconButton(
                  icon: const Icon(Icons.document_scanner_outlined,
                      color: AppColors.primary),
                  tooltip: l10n.scanReceipt,
                  onPressed: () async {
                    final result = await Navigator.push<ReceiptScanResult>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ReceiptScannerScreen()),
                    );
                    if (result?.amount != null) {
                      setState(() {
                        _amountCtrl.text =
                            result!.amount!.toStringAsFixed(2); // keep the paisa
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Date ──────────────────────────────────────────────────
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: subBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Flexible(child: Text(l10n.expenseDateLabel,
                        style: TextStyle(fontSize: 14, color: headingColor))),
                    const Spacer(),
                    Text(_dateText(l10n),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Category ──────────────────────────────────────────────
            Text(l10n.category,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: headingColor)),
            const SizedBox(height: 10),
            SizedBox(
              // Grows with the phone's text size
              height: MediaQuery.textScalerOf(context).scale(72),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categoryIcons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categoryIcons[i];
                  final selected = _category == cat['id'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _category = cat['id'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : subBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.primaryTint,
                          width: selected ? 2 : 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 22,
                            color: selected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Paid by ───────────────────────────────────────────────
            Text(l10n.paidBy,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: headingColor)),
            const SizedBox(height: 10),

            _members.isEmpty
                ? Container(
              height: 56,
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l10n.loadingMembers,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary))),
                  ],
                ),
              ),
            )
                : SizedBox(
              // Grows with the phone's text size
              height: MediaQuery.textScalerOf(context).scale(56),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _members.length,
                separatorBuilder: (_, __) =>
                const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = _members[i];
                  final selected = _paidBy == m['user_id'];
                  final color = _parseColor(
                      m['avatar_color'] as String);
                  return GestureDetector(
                    // The payer can't change when editing
                    onTap: _editing
                        ? null
                        : () => setState(
                            () => _paidBy = m['user_id'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : subBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.primaryTint,
                          width: selected ? 2 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: color,
                            backgroundImage: (m['avatar_url'] != null &&
                                (m['avatar_url'] as String).isNotEmpty)
                                ? NetworkImage(m['avatar_url'] as String)
                                : null,
                            child: (m['avatar_url'] == null ||
                                (m['avatar_url'] as String).isEmpty)
                                ? Text(
                              getInitial(m['name'] as String),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (m['name'] as String)
                                .split(' ')
                                .first,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Split tabs ────────────────────────────────────────────
            Text(l10n.split,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: headingColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SplitTypeBox(
                    label: l10n.equal,
                    selected: _splitType == 'equal',
                    onTap: () {
                      _splitTabCtrl.animateTo(0);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SplitTypeBox(
                    label: l10n.custom,
                    selected: _splitType == 'custom',
                    onTap: () {
                      _splitTabCtrl.animateTo(1);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SplitTypeBox(
                    label: l10n.percentSymbol,
                    selected: _splitType == 'percentage',
                    onTap: () {
                      _splitTabCtrl.animateTo(2);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Member split rows ─────────────────────────────────────
            if (_members.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: subBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l10n.loadingMembers,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary))),
                  ],
                ),
              )
            else
              ..._members.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final color =
                _parseColor(m['avatar_color'] as String);
                final included = m['included'] as bool;
                final amount =
                    double.tryParse(_amountCtrl.text) ?? 0;
                final activeCount = _members
                    .where((m) => m['included'] as bool)
                    .length;
                final equalShare =
                activeCount > 0 ? amount / activeCount : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: included
                          ? (dark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primaryTint)
                          : (dark
                          ? AppColors.primaryDark
                          : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: included
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.primaryTint.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox
                        LabeledTap(
                          label: AppLocalizations.of(context)!.includeInSplit(m['name'] as String),
                          onTap: () => setState(
                                  () => _members[i]['included'] = !included),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: included
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: included
                                    ? AppColors.primary
                                    : AppColors.primaryLight,
                              ),
                            ),
                            child: included
                                ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                                : null,
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Avatar
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: color,
                          backgroundImage: (m['avatar_url'] != null &&
                              (m['avatar_url'] as String).isNotEmpty)
                              ? NetworkImage(m['avatar_url'] as String)
                              : null,
                          child: (m['avatar_url'] == null ||
                              (m['avatar_url'] as String).isEmpty)
                              ? Text(
                            getInitial(m['name'] as String),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          )
                              : null,
                        ),

                        const SizedBox(width: 10),

                        // Name
                        Expanded(
                          child: Text(
                            m['name'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: included
                                  ? headingColor
                                  : headingColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),

                        // Amount per split type
                        if (_splitType == 'equal')
                          Text(
                            included
                                ? formatMoney(equalShare, widget.group.currency)
                                : '—',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: included
                                  ? AppColors.primary
                                  : AppColors.mutedText(context)
                                  .withValues(alpha: 0.4),
                            ),
                          ),

                        if (_splitType == 'custom' && included)
                          Container(
                            width: 90,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.6),
                                  width: 1.2),
                            ),
                            child: TextFormField(
                              key: ValueKey('custom-${m['user_id']}'),
                              initialValue: _initialField(m['custom_amount']),
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: AppColors.mutedText(context)
                                        .withValues(alpha: 0.4),
                                    fontSize: 13),
                                prefixText: '${widget.group.currency} ',
                                prefixStyle: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedText(context)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) => setState(() =>
                              _members[i]['custom_amount'] =
                                  double.tryParse(v) ?? 0.0),
                            ),
                          ),

                        if (_splitType == 'percentage' && included)
                          Container(
                            width: 68,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.6),
                                  width: 1.2),
                            ),
                            child: TextFormField(
                              key: ValueKey('percent-${m['user_id']}'),
                              initialValue: _initialField(m['percentage']),
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: AppColors.mutedText(context)
                                        .withValues(alpha: 0.4),
                                    fontSize: 13),
                                suffixText: l10n.percentSymbol,
                                suffixStyle: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) => setState(() =>
                              _members[i]['percentage'] =
                                  double.tryParse(v) ?? 0.0),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 14),

            // ── Notes ─────────────────────────────────────────────────
            SplitlyTextField(
              controller: _notesCtrl,
              label: l10n.notes,
              hint: l10n.additionalDetailsHint,
              prefixIcon: Icons.notes_rounded,
            ),

            const SizedBox(height: 14),

            // ── Recurring toggle (not when editing) ──────────────────
            if (!_editing) Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.primaryDark.withValues(alpha: 0.4) : AppColors.primaryTint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.repeat_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.repeatThisExpense,
                            style: TextStyle(
                                fontSize: 14,
                                color: dark
                                    ? AppColors.primaryTint
                                    : AppColors.primaryDark)),
                      ),
                      Switch(
                        value: _isRecurring,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isRecurring = v),
                      ),
                    ],
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _RecurChip(
                          label: l10n.daily,
                          selected: _recurEvery == 'daily',
                          onTap: () => setState(() => _recurEvery = 'daily'),
                        ),
                        const SizedBox(width: 8),
                        _RecurChip(
                          label: l10n.weekly,
                          selected: _recurEvery == 'weekly',
                          onTap: () => setState(() => _recurEvery = 'weekly'),
                        ),
                        const SizedBox(width: 8),
                        _RecurChip(
                          label: l10n.monthly,
                          selected: _recurEvery == 'monthly',
                          onTap: () => setState(() => _recurEvery = 'monthly'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Submit ────────────────────────────────────────────────
            SplitlyButton(
              label: _editing ? l10n.saveChanges : l10n.addExpense,
              isLoading: _isLoading,
              onPressed: _submit,
              icon: _editing ? Icons.check_rounded : Icons.add_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
class _RecurChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RecurChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primaryLight,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.mutedText(context),
          ),
        ),
      ),
    );
  }
}

class _SplitTypeBox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SplitTypeBox(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (dark ? AppColors.primaryDark : AppColors.primaryTint),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primaryTint,
            width: selected ? 0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : (dark ? AppColors.primaryTint : AppColors.primary),
          ),
        ),
      ),
    );
  }
}