import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../groups/models/group_model.dart';
import '../controllers/expenses_controller.dart';
import '../models/expense_model.dart';
import '../screens/expense_detail_sheet.dart';
import '../screens/expense_tile.dart';

// ── Filter state providers ────────────────────────────────────────────────────
final selectedCategoryFilterProvider =
StateProvider<String?>((ref) => null); // null = all

final selectedDateFilterProvider =
StateProvider<String>((ref) => 'all'); // all, today, week, month

final searchQueryProvider = StateProvider<String>((ref) => '');

class ExpenseHistoryScreen extends ConsumerWidget {
  final GroupModel group;
  const ExpenseHistoryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
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
            const Text('Expense History',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryTint)),
            Text(group.name,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primaryLight)),
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
                hintText: 'Search expenses...',
                hintStyle: TextStyle(
                    color: AppColors.primaryLight.withOpacity(0.5),
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
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _DateChip(label: 'All', value: 'all', ref: ref),
                _DateChip(label: 'Today', value: 'today', ref: ref),
                _DateChip(label: 'This week', value: 'week', ref: ref),
                _DateChip(
                    label: 'This month', value: 'month', ref: ref),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Category filter chips ───────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                    label: 'All',
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
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: TextStyle(color: AppColors.danger)),
              ),
              data: (expenses) {
                // Apply filters
                final filtered = _applyFilters(
                  expenses: expenses,
                  categoryFilter: categoryFilter,
                  dateFilter: dateFilter,
                  searchQuery: searchQuery,
                );

                if (filtered.isEmpty) {
                  return _EmptyFilterState(
                    hasFilters: categoryFilter != null ||
                        dateFilter != 'all' ||
                        searchQuery.isNotEmpty,
                  );
                }

                // Group by date
                final grouped = _groupByDate(filtered);

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
                                    color: AppColors.primaryLight,
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
                                  '${group.currency} ${entry.value.fold(0.0, (sum, e) => sum + e.amount).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryLight,
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
        final d = e.createdAt;
        return d.year == now.year &&
            d.month == now.month &&
            d.day == now.day;
      }).toList();
    } else if (dateFilter == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      result = result
          .where((e) => e.createdAt.isAfter(weekAgo))
          .toList();
    } else if (dateFilter == 'month') {
      result = result.where((e) {
        return e.createdAt.year == now.year &&
            e.createdAt.month == now.month;
      }).toList();
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
      List<ExpenseModel> expenses) {
    final map = <String, List<ExpenseModel>>{};
    final now = DateTime.now();

    for (final expense in expenses) {
      final d = expense.createdAt;
      String label;

      if (d.year == now.year &&
          d.month == now.month &&
          d.day == now.day) {
        label = 'TODAY';
      } else if (d.year == now.year &&
          d.month == now.month &&
          d.day == now.day - 1) {
        label = 'YESTERDAY';
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
        margin: const EdgeInsets.only(right: 8),
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
            color: selected ? Colors.white : AppColors.primaryLight,
          ),
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
        margin: const EdgeInsets.only(right: 8),
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
                    : AppColors.primaryLight,
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
                ? 'No matching expenses'
                : 'No expenses yet',
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
                ? 'Try changing or clearing the filters'
                : 'Add an expense to see it here',
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