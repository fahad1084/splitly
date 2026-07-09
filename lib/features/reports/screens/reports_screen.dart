import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../expenses/models/expense_model.dart';
import '../../groups/controllers/groups_controller.dart';
import '../../groups/models/group_model.dart';
import '../../../l10n/app_localizations.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedGroupIndex = 0;
  String _selectedPeriod = 'month'; // month, week, all
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;   // ✅ add this line
    final dark = isDark(context);
    final groupsAsync = ref.watch(groupsProvider);
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;

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
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryTint, size: 16),
          ),
        ),
          title: Text(l10n.spendingReports,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryTint)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.primaryLight,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: l10n.byCategory),
            Tab(text: l10n.byMember),
          ],
        ),
      ),
      body: groupsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: TextStyle(color: AppColors.danger))),
        data: (groups) {
          if (groups.isEmpty) return _EmptyState();

          // Pre-load expenses for all groups
          for (final g in groups) ref.watch(expensesProvider(g.id));

          final selectedGroup = groups[_selectedGroupIndex];
          final expenses =
              ref.watch(expensesProvider(selectedGroup.id)).value ??
                  [];
          final filtered = _filterByPeriod(expenses);

          return Column(
            children: [
              // ── Group selector ─────────────────────────────────────
              if (groups.length > 1)
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final selected = _selectedGroupIndex == i;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedGroupIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.primaryLight,
                              width: 0.5,
                            ),
                          ),
                          child: Text(groups[i].name,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.primaryLight)),
                        ),
                      );
                    },
                  ),
                ),

              // ── Period selector ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _PeriodChip(
                        label: l10n.thisMonth,   // was 'This month'
                        value: 'month',
                        selected: _selectedPeriod == 'month',
                        onTap: () => setState(
                                () => _selectedPeriod = 'month')),
                    const SizedBox(width: 8),
                    _PeriodChip(
                        label: l10n.thisWeek,    // was 'This week'
                        value: 'week',
                        selected: _selectedPeriod == 'week',
                        onTap: () => setState(
                                () => _selectedPeriod = 'week')),
                    const SizedBox(width: 8),
                    _PeriodChip(
                        label: l10n.allTime,     // was 'All time'
                        value: 'all',
                        selected: _selectedPeriod == 'all',
                        onTap: () =>
                            setState(() => _selectedPeriod = 'all')),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Total spent card ───────────────────────────────────
              _TotalCard(
                expenses: filtered,
                currency: selectedGroup.currency,
              ),

              // ── Charts ─────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _NoDataState()
                    : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // Tab 1: By Category
                    _CategoryTab(
                      expenses: filtered,
                      currency: selectedGroup.currency,
                    ),
                    // Tab 2: By Member
                    _MemberTab(
                      expenses: filtered,
                      currency: selectedGroup.currency,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ExpenseModel> _filterByPeriod(List<ExpenseModel> expenses) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return expenses
            .where((e) => e.createdAt.isAfter(weekAgo))
            .toList();
      case 'month':
        return expenses
            .where((e) =>
        e.createdAt.year == now.year &&
            e.createdAt.month == now.month)
            .toList();
      default:
        return expenses;
    }
  }
}

// ── Period chip ───────────────────────────────────────────────────────────────
class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip(
      {required this.label,
        required this.value,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
            selected ? AppColors.primary : AppColors.primaryLight,
            width: 0.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : AppColors.primaryLight)),
      ),
    );
  }
}

// ── Total card ────────────────────────────────────────────────────────────────
class _TotalCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String currency;
  const _TotalCard(
      {required this.expenses, required this.currency});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;   // ✅ add this
    final total =
    expenses.fold(0.0, (sum, e) => sum + e.amount);
    final dark = isDark(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(l10n.totalSpentLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryLight)),
                const SizedBox(height: 4),
                Text(
                  l10n.expensesCountLabel(expenses.length),                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryTint,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${expenses.length} expenses',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryLight)),
              const SizedBox(height: 4),
              Text(
                expenses.isEmpty
                    ? '-'
    :'$currency ${(total / expenses.length).toStringAsFixed(0)} ${l10n.avgLabel}',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Category tab ──────────────────────────────────────────────────────────────
class _CategoryTab extends StatefulWidget {
  final List<ExpenseModel> expenses;
  final String currency;
  const _CategoryTab(
      {required this.expenses, required this.currency});

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  int _touchedIndex = -1;

  // Category colors — teal palette
  static const _colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.primaryLight,
    Color(0xFF8B5CF6),
    AppColors.danger,
    Color(0xFFF59E0B),
    AppColors.accentDark,
    AppColors.primaryDark,
  ];

  static const _categoryIconMap = {
    'food': Icons.restaurant_rounded,
    'ration': Icons.shopping_cart_rounded,
    'utilities': Icons.bolt_rounded,
    'transport': Icons.directions_car_rounded,
    'rent': Icons.home_rounded,
    'entertainment': Icons.sports_esports_rounded,
    'medicine': Icons.medical_services_rounded,
    'travel': Icons.flight_rounded,
    'other': Icons.category_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);

    // Build category totals
    final categoryTotals = <String, double>{};
    for (final e in widget.expenses) {
      categoryTotals[e.category] =
          (categoryTotals[e.category] ?? 0) + e.amount;
    }
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
    sorted.fold(0.0, (sum, e) => sum + e.value);

    if (sorted.isEmpty) return _NoDataState();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        children: [
          // ── Pie chart ──────────────────────────────────────────────
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = response
                          .touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final isTouched = i == _touchedIndex;
                  final pct = entry.value.value / total * 100;
                  return PieChartSectionData(
                    color: _colors[i % _colors.length],
                    value: entry.value.value,
                    title: isTouched
                        ? '${pct.toStringAsFixed(1)}%'
                        : '',
                    radius: isTouched ? 55 : 45,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),

          // Center total label
          const SizedBox(height: 8),

          // ── Legend + breakdown list ────────────────────────────────
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.key;
            final amount = entry.value.value;
            final pct = amount / total * 100;
            final color = _colors[i % _colors.length];
            final icon = _categoryIconMap[entry.value.key] ??
                Icons.category_rounded;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dark ? AppColors.primaryDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dark
                      ? color.withOpacity(0.3)
                      : AppColors.primaryTint,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // Color dot + icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // Category name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capitalize(entry.value.key),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: dark
                                  ? AppColors.primaryTint
                                  : AppColors.primaryDark),
                        ),
                        const SizedBox(height: 4),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: amount / total,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Amount + pct
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.currency} ${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: dark
                                ? AppColors.primaryTint
                                : AppColors.primaryDark),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryLight),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Member tab ────────────────────────────────────────────────────────────────
class _MemberTab extends StatefulWidget {
  final List<ExpenseModel> expenses;
  final String currency;
  const _MemberTab(
      {required this.expenses, required this.currency});

  @override
  State<_MemberTab> createState() => _MemberTabState();
}

class _MemberTabState extends State<_MemberTab> {
  int _touchedIndex = -1;

  static const _colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.primaryLight,
    Color(0xFF8B5CF6),
    AppColors.danger,
  ];

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);

    // Build per-member totals (who paid how much)
    final memberTotals = <String, double>{};
    final memberNames = <String, String>{};
    for (final e in widget.expenses) {
      memberTotals[e.paidBy] =
          (memberTotals[e.paidBy] ?? 0) + e.amount;
      memberNames[e.paidBy] = e.paidByName;
    }

    final sorted = memberTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
    sorted.fold(0.0, (sum, e) => sum + e.value);

    if (sorted.isEmpty) return _NoDataState();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        children: [
          // ── Bar chart ──────────────────────────────────────────────
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: sorted.first.value * 1.3,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final name =
                          memberNames[sorted[group.x].key] ??
                              'Unknown';
                      return BarTooltipItem(
                        '$name\n${widget.currency} ${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.spot == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex =
                          response.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= sorted.length)
                          return const SizedBox();
                        final name =
                            memberNames[sorted[i].key] ?? '?';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            name.split(' ').first,
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primaryLight),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                  sorted.first.value / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.primaryTint.withOpacity(0.3),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final isTouched = i == _touchedIndex;
                  final color = _colors[i % _colors.length];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value,
                        color: isTouched
                            ? color
                            : color.withOpacity(0.7),
                        width: 24,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: sorted.first.value * 1.3,
                          color: color.withOpacity(0.05),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Member breakdown list ──────────────────────────────────
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final name = memberNames[entry.value.key] ?? 'Unknown';
            final amount = entry.value.value;
            final pct = amount / total * 100;
            final color = _colors[i % _colors.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dark ? AppColors.primaryDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dark
                      ? color.withOpacity(0.3)
                      : AppColors.primaryTint,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w500,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: dark
                                    ? AppColors.primaryTint
                                    : AppColors.primaryDark)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: amount / total,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.currency} ${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: dark
                                ? AppColors.primaryTint
                                : AppColors.primaryDark),
                      ),
                      Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryLight)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;   // ✅ add this
    final dark = isDark(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: dark ? AppColors.primaryDark : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart_rounded,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
        Text(l10n.noGroupsYet,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
          const SizedBox(height: 8),
        Text(l10n.createGroupAddExpensesDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.primary, height: 1.5)),
        ],
      ),
    );
  }
}

class _NoDataState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;   // ✅ add this
    final dark = isDark(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: dark ? AppColors.primaryDark : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart_rounded,
                size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
        Text(l10n.noExpensesInPeriod,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: dark ? AppColors.primaryTint : AppColors.primaryDark)),
          const SizedBox(height: 8),
        Text(l10n.tryDifferentPeriod,
              style: TextStyle(fontSize: 13, color: AppColors.primary)),
        ],
      ),
    );
  }
}