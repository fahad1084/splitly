import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../groups/models/group_model.dart';
import '../../expenses/controllers/expenses_controller.dart';
import 'export_service.dart';

// ── Public helper — call this from anywhere ─────────────────────────────────
Future<void> showExportSheet(BuildContext context, GroupModel group) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ExportSheet(group: group),
  );
}

class ExportSheet extends ConsumerStatefulWidget {
  final GroupModel group;
  const ExportSheet({super.key, required this.group});

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  bool _exportingPdf = false;
  bool _exportingCsv = false;

  Future<void> _exportPdf() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exportingPdf = true);
    try {
      final expenses = ref.read(expensesProvider(widget.group.id)).value ?? [];
      if (expenses.isEmpty) {
        if (mounted) showErrorSnack(context, l10n.noExpensesToExport);
        return;
      }
      await ExportService.exportToPdf(group: widget.group, expenses: expenses);
      if (mounted) {
        showSuccessSnack(context, l10n.pdfExportedSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, l10n.pdfExportFailed);
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportCsv() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exportingCsv = true);
    try {
      final expenses = ref.read(expensesProvider(widget.group.id)).value ?? [];
      if (expenses.isEmpty) {
        if (mounted) showErrorSnack(context, l10n.noExpensesToExport);
        return;
      }
      await ExportService.exportToCsv(group: widget.group, expenses: expenses);
      if (mounted) {
        showSuccessSnack(context, l10n.csvExportedSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, l10n.csvExportFailed);
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? AppColors.primaryDark : Colors.white;
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(l10n.exportGroupTitle(widget.group.name),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 4),
            Text(l10n.downloadExpenseRecords,
                style: TextStyle(fontSize: 13, color: AppColors.primary)),
            const SizedBox(height: 24),
            _ExportOptionTile(
              icon: Icons.picture_as_pdf_outlined,
              iconColor: AppColors.danger,
              title: l10n.exportAsPdf,
              subtitle: l10n.pdfSubtitle,
              isLoading: _exportingPdf,
              onTap: _exportingPdf || _exportingCsv ? null : _exportPdf,
            ),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.table_chart_outlined,
              iconColor: AppColors.success,
              title: l10n.exportAsCsv,
              subtitle: l10n.csvSubtitle,
              isLoading: _exportingCsv,
              onTap: _exportingPdf || _exportingCsv ? null : _exportCsv,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ExportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final borderColor = dark ? AppColors.primary.withOpacity(0.3) : AppColors.primaryTint;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.primaryLight),
          ],
        ),
      ),
    );
  }
}