import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/groups_controller.dart';

// Supported currencies for Splitly
const _currencies = [
  {'code': 'PKR', 'name': 'Pakistani Rupee'},
  {'code': 'USD', 'name': 'US Dollar'},
  {'code': 'AED', 'name': 'UAE Dirham'},
  {'code': 'SAR', 'name': 'Saudi Riyal'},
  {'code': 'GBP', 'name': 'British Pound'},
  {'code': 'EUR', 'name': 'Euro'},
];

// Group type icons
const _groupTypes = [
  {'label': 'Home', 'icon': Icons.home_rounded},
  {'label': 'Trip', 'icon': Icons.flight_rounded},
  {'label': 'Friends', 'icon': Icons.group_rounded},
  {'label': 'Office', 'icon': Icons.work_rounded},
  {'label': 'Family', 'icon': Icons.favorite_rounded},
  {'label': 'Other', 'icon': Icons.category_rounded},
];

void showCreateGroupSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateGroupSheet(),
  );
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _selectedCurrency = 'PKR';
  int _selectedTypeIndex = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    final error = await ref.read(groupsProvider.notifier).createGroup(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      currency: _selectedCurrency,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      showErrorSnack(context, error);
      print('=== CREATE GROUP SHEET ERROR: $error ===');
    } else {
      showSuccessSnack(context, l10n.groupCreated);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? AppColors.primaryDark : Colors.white;
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final labelColor = AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────────────
              Text(
                l10n.createAGroup,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: headingColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.startSplittingCircle,
                style: TextStyle(fontSize: 13, color: labelColor),
              ),

              const SizedBox(height: 24),

              // ── Group type selector ──────────────────────────────────────
              Text(l10n.groupType,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: headingColor)),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _groupTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final selected = _selectedTypeIndex == i;
                    final type = _groupTypes[i];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTypeIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 64,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : dark
                              ? AppColors.primaryDark.withOpacity(0.5)
                              : AppColors.primaryTint,
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
                              type['icon'] as IconData,
                              size: 22,
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type['label'] as String,
                              style: TextStyle(
                                fontSize: 10,
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

              // ── Group name ───────────────────────────────────────────────
              Text(l10n.groupName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: headingColor)),
              const SizedBox(height: 8),
              SplitlyTextField(
                controller: _nameCtrl,
                label: l10n.groupName,
                hint: 'e.g. Apartment, Dubai Trip',
                prefixIcon: Icons.group_outlined,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.groupNameRequired;
                  }
                  if (v.trim().length < 2) return l10n.groupNameTooShort;
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Description (optional) ───────────────────────────────────
              Text(l10n.descriptionOptional,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: headingColor)),
              const SizedBox(height: 8),
              SplitlyTextField(
                controller: _descCtrl,
                label: l10n.description,
                hint: 'e.g. Shared flat expenses',
                prefixIcon: Icons.notes_rounded,
              ),

              const SizedBox(height: 16),

              // ── Currency ─────────────────────────────────────────────────
              Text(l10n.currency,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: headingColor)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: dark
                      ? AppColors.primaryDark
                      : AppColors.primaryTint.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: dark ? AppColors.primaryDark : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary),
                    style: TextStyle(
                      color: dark ? AppColors.primaryTint : AppColors.primaryDark,
                      fontSize: 15,
                    ),
                    items: _currencies.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['code'],
                        child: Row(
                          children: [
                            Text(
                              c['code']!,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              c['name']!,
                              style: TextStyle(
                                fontSize: 13,
                                color: dark
                                    ? AppColors.primaryTint.withOpacity(0.7)
                                    : AppColors.primaryDark.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCurrency = v ?? 'PKR'),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Create button ─────────────────────────────────────────────
              SplitlyButton(
                label: l10n.createGroup,
                isLoading: _isLoading,
                onPressed: _createGroup,
                icon: Icons.add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}