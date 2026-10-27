import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../groups/models/group_model.dart';
import '../controllers/expenses_controller.dart';
import '../models/expense_model.dart';
import '../screens/expense_detail_sheet.dart';
import '../screens/expense_tile.dart';
import '../../../core/utils/money_format.dart';

// ── Filter state providers ────────────────────────────────────────────────────
final selectedCategoryFilterProvider =
StateProvider<String?>((ref) => null); // null = all

final selectedDateFilterProvider =
StateProvider<String>((ref) => 'all'); // all, today, week, month, custom

final customDateRangeProvider =
StateProvider<DateTimeRange?>((ref) => null);

final searchQueryProvider = StateProvider<String>((ref) => '');

class ExpenseHistoryScreen extends ConsumerWidget {
  final GroupModel group;
  const ExpenseHistoryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final expensesAsync = ref.watch(expensesProvider(group.id));
    final categoryFilter = ref.watch(selectedCategoryFilterProvider);
    final dateFilter = ref.watch(selectedDateFilterProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final currentUserId =
        ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: LabeledTap(
          label: AppLocalizations.of(context)!.back,
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primaryTint,
              size: 16,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.expenseHistory,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryTint)),
            Text(group.name,
                style: TextStyle(
                    fontSize: 12, color: AppColors.mutedText(context))),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: (v) => ref
                  .read(searchQueryProvider.notifier)
                  .state = v,
              style: TextStyle(
                  fontSize: 14,
                  color: dark
                      ? AppColors.primaryTint
                      : AppColors.primaryDark),
              decoration: InputDecoration(
                hintText: l10n.searchExpenses,
                hintStyle: TextStyle(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.primary, size: 20),
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Date filter chips ───────────────────────────────────────
          SizedBox(
            // Grows with the phone's text size
            height: MediaQuery.textScalerOf(context).scale(36),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _DateChip(label: l10n.all, value: 'all', ref: ref),
                _DateChip(label: l10n.today, value: 'today', ref: ref),
                _DateChip(label: l10n.thisWeek, value: 'week', ref: ref),
                _DateChip(
                    label: l10n.thisMonth, value: 'month', ref: ref),
                _CustomRangeChip(ref: ref),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Category filter chips ───────────────────────────────────
          SizedBox(
            // Grows with the phone's text size
            height: MediaQuery.textScalerOf(context).scale(36),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                    label: l10n.all,
                    value: null,
                    icon: Icons.grid_view_rounded,
                    ref: ref),
                ..._categoryIcons.map((c) => _CategoryChip(
                  label: c['label'] as String,
                  value: c['id'] as String,
                  icon: c['icon'] as IconData,
                  ref: ref,
                )),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Expense list ────────────────────────────────────────────
          Expanded(
            child: expensesAsync.when(
              skipError: true, // keep the last data if a reload fails
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (_, __) => ErrorRetry(
                onRetry: () => ref.invalidate(expensesProvider(group.id)),
              ),
              data: (expenses) {
                // Apply filters
                final filtered = _applyFilters(
                  expenses: expenses,
                  categoryFilter: categoryFilter,
                  dateFilter: dateFilter,
                  customRange: ref.watch(customDateRangeProvider),
                  searchQuery: searchQuery,
                );

                if (filtered.isEmpty) {
                  return _EmptyFilterState(
                    hasFilters: categoryFilter != null ||
                        dateFilter != 'all' ||
                        ref.watch(customDateRangeProvider) != null ||
                        searchQuery.isNotEmpty,
                  );
                }

                // Group by date
                final grouped = _groupByDate(filtered, l10n);

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref
                      .read(expensesProvider(group.id).notifier)
                      .refresh(),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: grouped.length,
                    itemBuilder: (_, i) {
                      final entry = grouped.entries.elementAt(i);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                20, 16, 20, 8),
                            child: Row(
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.mutedText(context),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Divider(
                                    color: dark
                                        ? AppColors.primaryDark
                                        : AppColors.primaryTint,
                                    thickness: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Day total
                                Text(
                                  formatMoney(entry.value.fold(0.0, (sum, e) => sum + e.amount), group.currency),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedText(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Expenses for this date
                          ...entry.value.map((expense) =>
                              GestureDetector(
                                onTap: () =>
                                    showExpenseDetailSheet(
                                        context, expense, group),
                                child: ExpenseTile(
                                  expense: expense,
                                  currentUserId: currentUserId,
                                  onDelete: () => ref
                                      .read(expensesProvider(
                                      group.id)
                                      .notifier)
                                      .deleteExpense(expense.id),
                                ),
                              )),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter logic ────────────────────────────────────────────────────────────
  List<ExpenseModel> _applyFilters({
    required List<ExpenseModel> expenses,
    required String? categoryFilter,
    required String dateFilter,
    required DateTimeRange? customRange,
    required String searchQuery,
  }) {
    var result = expenses;

    // Category filter
    if (categoryFilter != null) {
      result = result
          .where((e) => e.category == categoryFilter)
          .toList();
    }

    // Date filter
    final now = DateTime.now();
    if (dateFilter == 'today') {
      result = result.where((e) {
        final d = e.expenseDate;
        return d.year == now.year &&
            d.month == now.month &&
            d.day == now.day;
      }).toList();
    } else if (dateFilter == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      result = result
          .where((e) => e.expenseDate.isAfter(weekAgo))
          .toList();
    } else if (dateFilter == 'month') {
      result = result.where((e) {
        return e.expenseDate.year == now.year &&
            e.expenseDate.month == now.month;
      }).toList();
    } else if (dateFilter == 'custom' && customRange != null) {
      final start = customRange.start;
      final end = customRange.end
          .add(const Duration(hours: 23, minutes: 59, seconds: 59));
      result = result
          .where((e) =>
      e.expenseDate
          .isAfter(start.subtract(const Duration(seconds: 1))) &&
          e.expenseDate.isBefore(end))
          .toList();
    }

    // Search filter
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result
          .where((e) =>
      e.title.toLowerCase().contains(q) ||
          e.paidByName.toLowerCase().contains(q))
          .toList();
    }

    return result;
  }

  // ── Group expenses by formatted date string ─────────────────────────────────
  Map<String, List<ExpenseModel>> _groupByDate(
      List<ExpenseModel> expenses, AppLocalizations l10n) {
    final map = <String, List<ExpenseModel>>{};
    final now = DateTime.now();

    for (final expense in expenses) {
      final d = expense.expenseDate;
      String label;

      if (d.year == now.year &&
          d.month == now.month &&
          d.day == now.day) {
        label = l10n.todayCaps;
      } else if (d.year == now.year &&
          d.month == now.month &&
          d.day == now.day - 1) {
        label = l10n.yesterday;
      } else {
        label =
            '${_monthName(d.month)} ${d.day}, ${d.year}'.toUpperCase();
      }

      map.putIfAbsent(label, () => []).add(expense);
    }

    return map;
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month];
  }
}

// ── Category icon map ─────────────────────────────────────────────────────────
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

// ── Date filter chip ──────────────────────────────────────────────────────────
class _DateChip extends ConsumerWidget {
  final String label;
  final String value;
  final WidgetRef ref;
  const _DateChip(
      {required this.label, required this.value, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(selectedDateFilterProvider) == value;
    return GestureDetector(
      onTap: () => ref
          .read(selectedDateFilterProvider.notifier)
          .state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primaryLight,
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

// ── Custom date-range chip ──────────────────────────────────────────────────
class _CustomRangeChip extends ConsumerWidget {
  final WidgetRef ref;
  const _CustomRangeChip({required this.ref});

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(selectedDateFilterProvider) == 'custom';
    final range = ref.watch(customDateRangeProvider);
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
          initialDateRange: range ??
              DateTimeRange(
                  start: now.subtract(const Duration(days: 30)),
                  end: now),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                primaryContainer: AppColors.primaryTint,
                onPrimaryContainer: AppColors.primaryDark,
                secondary: AppColors.primary,
                onSecondary: Colors.white,
                secondaryContainer: AppColors.primaryTint,
                onSecondaryContainer: AppColors.primaryDark,
                surface: Colors.white,
                onSurface: AppColors.primaryDark,
                outline: AppColors.primaryTint,
              ),
              datePickerTheme: DatePickerThemeData(
                backgroundColor: Colors.white,
                headerBackgroundColor: AppColors.primaryDark,
                headerForegroundColor: AppColors.primaryTint,
                rangePickerBackgroundColor: Colors.white,
                rangePickerHeaderBackgroundColor: AppColors.primaryDark,
                rangePickerHeaderForegroundColor: AppColors.primaryTint,
                rangeSelectionBackgroundColor: AppColors.primaryTint,
                todayForegroundColor:
                WidgetStateProperty.all(AppColors.primary),
                todayBorder:
                const BorderSide(color: AppColors.primary, width: 1),
                dayForegroundColor: WidgetStateProperty.resolveWith(
                        (states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return AppColors.primaryDark;
                    }),
                dayBackgroundColor: WidgetStateProperty.resolveWith(
                        (states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary;
                      }
                      return null;
                    }),
                confirmButtonStyle:
                TextButton.styleFrom(foregroundColor: AppColors.primary),
                cancelButtonStyle: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark.withValues(alpha: 0.6)),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          ref.read(customDateRangeProvider.notifier).state = picked;
          ref.read(selectedDateFilterProvider.notifier).state = 'custom';
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primaryLight,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range_rounded,
                size: 14,
                color: selected ? Colors.white : AppColors.primaryLight),
            const SizedBox(width: 4),
            Text(
              selected && range != null
                  ? '${_fmt(range.start)} – ${_fmt(range.end)}'
                  : l10n.customRange,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category filter chip ──────────────────────────────────────────────────────
class _CategoryChip extends ConsumerWidget {
  final String label;
  final String? value;
  final IconData icon;
  final WidgetRef ref;
  const _CategoryChip(
      {required this.label,
        required this.value,
        required this.icon,
        required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(selectedCategoryFilterProvider) == value;
    return GestureDetector(
      onTap: () => ref
          .read(selectedCategoryFilterProvider.notifier)
          .state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primaryLight,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color:
              selected ? Colors.white : AppColors.primaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : AppColors.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty filter state ────────────────────────────────────────────────────────
class _EmptyFilterState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyFilterState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color:
              dark ? AppColors.primaryDark : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters
                  ? Icons.filter_list_off_rounded
                  : Icons.receipt_long_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? l10n.noMatchingExpenses
                : l10n.noExpensesYet,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: dark
                  ? AppColors.primaryTint
                  : AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? l10n.tryChangingFilters
                : l10n.addExpenseToSeeHere,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}