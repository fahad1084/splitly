import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitly/features/auth/controllers/auth_controller.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../groups/models/group_model.dart';
import '../controllers/expenses_controller.dart';
import '../models/expense_model.dart';
import 'receipt_scanner_screen.dart';

void showAddExpenseSheet(BuildContext context, GroupModel group) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddExpenseSheet(group: group),
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
  const _AddExpenseSheet({required this.group});

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

  List<Map<String, dynamic>> _members = [];

  late TabController _splitTabCtrl;

  @override
  void initState() {
    super.initState();
    _splitTabCtrl = TabController(length: 3, vsync: this);
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
    // ✅ FIX: Load members here instead of initState
    // didChangeDependencies is called after providers are ready
    _loadMembers();
  }

  void _loadMembers() {
    final currentUserId =
        ref.read(currentUserProvider)?.id ?? '';

    // Read members synchronously from the provider cache
    final membersAsync =
    ref.read(groupMembersProvider(widget.group.id));

    membersAsync.whenData((members) {
      if (_members.isNotEmpty) return; // already loaded
      final loaded = members.map((m) {
        final profile =
            m['profiles'] as Map<String, dynamic>? ?? {};
        return {
          'user_id': profile['id'] as String? ?? '',
          'name': profile['full_name'] as String? ?? 'Unknown',
          'avatar_color':
          profile['avatar_color'] as String? ?? '#0F766E',
          'included': true,
          'custom_amount': 0.0,
          'percentage': 0.0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _members = loaded;
          _paidBy = currentUserId;
        });
      }
    });
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
    if (_titleCtrl.text.trim().isEmpty) {
      showErrorSnack(context, 'Please enter a title');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      showErrorSnack(context, 'Please enter a valid amount');
      return;
    }
    if (_members.isEmpty) {
      showErrorSnack(context, 'No members to split with');
      return;
    }
    if (_paidBy == null) {
      showErrorSnack(context, 'Please select who paid');
      return;
    }

    if (_splitType == 'custom') {
      final total = _members
          .where((m) => m['included'] as bool)
          .fold(0.0, (sum, m) => sum + (m['custom_amount'] as double));
      if ((total - amount).abs() > 0.01) {
        showErrorSnack(context,
            'Custom amounts must add up to ${widget.group.currency} $amount');
        return;
      }
    }

    if (_splitType == 'percentage') {
      final total = _members
          .where((m) => m['included'] as bool)
          .fold(0.0, (sum, m) => sum + (m['percentage'] as double));
      if ((total - 100).abs() > 0.01) {
        showErrorSnack(context, 'Percentages must add up to 100%');
        return;
      }
    }

    setState(() => _isLoading = true);

    final error = await ref
        .read(expensesProvider(widget.group.id).notifier)
        .addExpense(
      title: _titleCtrl.text.trim(),
      amount: amount,
      category: _category,
      paidBy: _paidBy!,
      splitType: _splitType,
      members: _members,
      currency: widget.group.currency,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      showErrorSnack(context, error);
    } else {
      showSuccessSnack(context, 'Expense added!');
      Navigator.pop(context);
    }
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
    final dark = isDark(context);
    final sheetBg = dark ? const Color(0xFF042F2E) : Colors.white;
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final subBg = dark ? AppColors.primaryDark : AppColors.primaryTint;

    // ✅ FIX: Also watch the provider so sheet rebuilds when members load
    final membersAsync =
    ref.watch(groupMembersProvider(widget.group.id));

    // Update _members when provider data arrives
    membersAsync.whenData((members) {
      if (_members.isEmpty && members.isNotEmpty) {
        final currentUserId =
            ref.read(currentUserProvider)?.id ?? '';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _members = members.map((m) {
              final profile =
                  m['profiles'] as Map<String, dynamic>? ?? {};
              return {
                'user_id': profile['id'] as String? ?? '',
                'name': profile['full_name'] as String? ?? 'Unknown',
                'avatar_color':
                profile['avatar_color'] as String? ?? '#0F766E',
                'included': true,
                'custom_amount': 0.0,
                'percentage': 0.0,
              };
            }).toList();
            _paidBy = currentUserId;
          });
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

            Text('Add Expense',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: headingColor,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(widget.group.name,
                style:
                TextStyle(fontSize: 13, color: AppColors.primary)),

            const SizedBox(height: 24),

            // ── Title ─────────────────────────────────────────────────
            SplitlyTextField(
              controller: _titleCtrl,
              label: 'What was it for?',
              hint: 'e.g. Dinner, Groceries, Taxi',
              prefixIcon: Icons.receipt_outlined,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),

            const SizedBox(height: 14),

            // ── Amount ────────────────────────────────────────────────
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
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: headingColor),
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                hintStyle: TextStyle(
                    color: AppColors.primaryLight.withOpacity(0.4),
                    fontSize: 28),
                prefixIcon: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Text(widget.group.currency,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary)),
                ),
                prefixIconConstraints: const BoxConstraints(),
                // ✅ NEW — Receipt scan button
                suffixIcon: IconButton(
                  icon: const Icon(Icons.document_scanner_outlined,
                      color: AppColors.primary),
                  tooltip: 'Scan Receipt',
                  onPressed: () async {
                    final result = await Navigator.push<ReceiptScanResult>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ReceiptScannerScreen()),
                    );
                    if (result?.amount != null) {
                      setState(() {
                        _amountCtrl.text =
                            result!.amount!.toStringAsFixed(0);
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Category ──────────────────────────────────────────────
            Text('Category',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: headingColor)),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
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
                      width: 64,
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
                              fontSize: 9,
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
            Text('Paid by',
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
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Loading members...',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            )
                : SizedBox(
              height: 56,
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
                    onTap: () => setState(
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
                            child: Text(
                              (m['name'] as String)
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500),
                            ),
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
            Text('Split',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: headingColor)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _splitTabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.primary,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Equal'),
                  Tab(text: 'Custom'),
                  Tab(text: '%'),
                ],
              ),
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
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text('Loading members...',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primary)),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: included
                          ? AppColors.primaryTint
                          : AppColors.primaryTint.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Checkbox
                      GestureDetector(
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
                        child: Text(
                          (m['name'] as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
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
                                : headingColor.withOpacity(0.4),
                          ),
                        ),
                      ),

                      // Amount per split type
                      if (_splitType == 'equal')
                        Text(
                          included
                              ? '${widget.group.currency} ${equalShare.toStringAsFixed(0)}'
                              : '—',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: included
                                ? AppColors.primary
                                : AppColors.primaryLight
                                .withOpacity(0.4),
                          ),
                        ),

                      if (_splitType == 'custom' && included)
                        SizedBox(
                          width: 90,
                          child: TextField(
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                  color: AppColors.primaryLight
                                      .withOpacity(0.4),
                                  fontSize: 13),
                              prefixText: '${widget.group.currency} ',
                              prefixStyle: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryLight),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => setState(() =>
                            _members[i]['custom_amount'] =
                                double.tryParse(v) ?? 0.0),
                          ),
                        ),

                      if (_splitType == 'percentage' && included)
                        SizedBox(
                          width: 60,
                          child: TextField(
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                  color: AppColors.primaryLight
                                      .withOpacity(0.4),
                                  fontSize: 13),
                              suffixText: '%',
                              suffixStyle: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13),
                              border: InputBorder.none,
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
                );
              }),

            const SizedBox(height: 14),

            // ── Notes ─────────────────────────────────────────────────
            SplitlyTextField(
              controller: _notesCtrl,
              label: 'Notes (optional)',
              hint: 'Any additional details...',
              prefixIcon: Icons.notes_rounded,
            ),

            const SizedBox(height: 28),

            // ── Submit ────────────────────────────────────────────────
            SplitlyButton(
              label: 'Add Expense',
              isLoading: _isLoading,
              onPressed: _submit,
              icon: Icons.add_rounded,
            ),
          ],
        ),
      ),
    );
  }
}