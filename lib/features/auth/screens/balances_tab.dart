import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';

class BalancesTab extends StatelessWidget {
  const BalancesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final textColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;
    final iconBg =
    dark ? AppColors.primaryDark : AppColors.primaryTint;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Balances',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryTint,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Balances',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All your balances across groups will appear here once you add expenses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}