import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitly/config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/balances_controller.dart';
import '../models/balance_model.dart';
import '../../../core/utils/string_utils.dart';

void showSettleUpSheet(BuildContext context, DebtModel debt) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettleUpSheet(debt: debt),
  );
}

class _SettleUpSheet extends ConsumerStatefulWidget {
  final DebtModel debt;
  const _SettleUpSheet({required this.debt});

  @override
  ConsumerState<_SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<_SettleUpSheet> {
  bool _isLoading = false;
  final currentUserId =
      SupabaseConfig.client.auth.currentUser?.id ?? '';

  Future<void> _settle() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    final error = await ref.read(settleUpProvider.notifier).settleUp(
      groupId: widget.debt.groupId,
      paidBy: widget.debt.fromUserId,
      paidTo: widget.debt.toUserId,
      amount: widget.debt.amount,
      currency: widget.debt.currency,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      showErrorSnack(context, error);
    } else {
      showSuccessSnack(context, l10n.settlementRecorded);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final sheetBg = dark ? const Color(0xFF042F2E) : Colors.white;
    final headingColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final cardBg = dark ? AppColors.primaryDark : AppColors.primaryTint;

    final iAmPaying = widget.debt.fromUserId == currentUserId;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),

          const SizedBox(height: 16),

          Text(l10n.settleUp,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: headingColor,
                  letterSpacing: -0.5)),

          const SizedBox(height: 24),

          // Debt summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // From → To
                Row(
                  children: [
                    // From avatar
                    _Avatar(
                      name: widget.debt.fromUserName,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            iAmPaying
                                ? l10n.youPay
                                : l10n.userPays(widget.debt.fromUserName),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          Text(
                            widget.debt.toUserName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: headingColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Arrow
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // To avatar
                    _Avatar(
                      name: widget.debt.toUserName,
                      color: AppColors.success,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Amount
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l10n.amountToSettle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.debt.currency} ${widget.debt.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.settleUpInfo,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Confirm button
          SplitlyButton(
            label: l10n.confirmSettlement,
            isLoading: _isLoading,
            onPressed: _settle,
            icon: Icons.check_rounded,
          ),

          const SizedBox(height: 12),

          // Cancel
          SplitlyButton(
            label: l10n.cancel,
            isOutline: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  const _Avatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        getInitial(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
    );
  }
}