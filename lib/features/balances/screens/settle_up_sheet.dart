import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitly/config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/balances_controller.dart';
import '../models/balance_model.dart';
import '../../expenses/controllers/expenses_controller.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/utils/money_format.dart';

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
  late final TextEditingController _amountCtrl;

  // The most that can be paid now: the debt minus payments already
  // waiting for confirmation (the database checks the same rule).
  int get _maxPaisa =>
      toPaisa(widget.debt.amount) - toPaisa(widget.debt.pendingAmount);

  bool get _iAmReceiving => widget.debt.toUserId == currentUserId;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: fromPaisa(_maxPaisa > 0 ? _maxPaisa : 0).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _settle() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || toPaisa(amount) <= 0) {
      showErrorSnack(context, l10n.pleaseEnterValidAmount);
      return;
    }
    if (toPaisa(amount) > _maxPaisa) {
      showErrorSnack(context, l10n.amountMoreThanOwed);
      return;
    }

    setState(() => _isLoading = true);

    final error = await ref.read(settleUpProvider.notifier).recordSettlement(
      groupId: widget.debt.groupId,
      paidBy: widget.debt.fromUserId,
      paidTo: widget.debt.toUserId,
      amount: amount,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      showErrorSnack(context, switch (error) {
        'AMOUNT_TOO_HIGH' => l10n.amountMoreThanOwed,
        'INVALID_AMOUNT' => l10n.pleaseEnterValidAmount,
        'NO_DEBT' => l10n.nothingOwedHere,
        _ => l10n.somethingWentWrong,
      });
    } else {
      // Receiver → counts at once. Debtor → waits for the receiver.
      showSuccessSnack(context,
          _iAmReceiving ? l10n.settlementRecorded : l10n.paymentWaitingConfirmation);
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
      // Lift the sheet above the keyboard (the amount can be edited)
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 40 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                              color: AppColors.mutedText(context),
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
                        color: AppColors.success.withValues(alpha: 0.1),
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
                          color: AppColors.mutedText(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Editable: partial payments are allowed
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _amountCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: AppColors.successText(context),
                            letterSpacing: -1,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixText: '${widget.debt.currency} ',
                            prefixStyle: TextStyle(
                                fontSize: 18, color: AppColors.successText(context)),
                          ),
                        ),
                      ),
                      Text(
                        l10n.upToAmount(
                            formatMoney(fromPaisa(_maxPaisa), widget.debt.currency)),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText(context),
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
                    _iAmReceiving
                        ? l10n.settleReceiverInfo
                        : l10n.settlePendingInfo(widget.debt.toUserName),
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
            label: _iAmReceiving ? l10n.markAsReceived : l10n.iPaid,
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
      backgroundColor: color.withValues(alpha: 0.15),
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