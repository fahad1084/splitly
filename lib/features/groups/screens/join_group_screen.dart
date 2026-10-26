import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/groups_controller.dart';
import 'package:splitly/core/utils/app_logger.dart';

// ── Provider to join a group ──────────────────────────────────────────────────
final joinGroupProvider =
StateNotifierProvider<JoinGroupController, AsyncValue<void>>(
      (ref) => JoinGroupController(ref),
);

class JoinGroupController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  JoinGroupController(this._ref) : super(const AsyncValue.data(null));

  Future<String?> joinGroup(String inviteCode) async {
    state = const AsyncValue.loading();
    try {
      final userId =
          SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return 'Not signed in';
      }

      // One RPC checks the invite code and adds us as a 'member' — direct
      // inserts into group_members are blocked by RLS, so the code can't be
      // skipped. No row back = invalid code.
      final List<dynamic> rows = await SupabaseConfig.client
          .rpc('join_group_by_code',
          params: {'p_invite_code': inviteCode.trim().toLowerCase()});

      if (rows.isEmpty) {
        state = const AsyncValue.data(null);
        return 'INVALID_CODE'; // handled in UI with l10n
      }

      final groupName = rows.first['group_name'] as String;
      if (rows.first['already_member'] == true) {
        state = const AsyncValue.data(null);
        return 'ALREADY_MEMBER::$groupName'; // handled in UI with l10n
      }

      // Refresh groups list
      await _ref.read(groupsProvider.notifier).refresh();

      state = const AsyncValue.data(null);
      return null; // success
    } catch (e) {
      logDebug('=== JOIN GROUP ERROR: $e ===');
      state = const AsyncValue.data(null);
      return 'Error: $e';
    }
  }
}

// ── Join Group Sheet ──────────────────────────────────────────────────────────
void showJoinGroupSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _JoinGroupSheet(),
  );
}

class _JoinGroupSheet extends ConsumerStatefulWidget {
  const _JoinGroupSheet();

  @override
  ConsumerState<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<_JoinGroupSheet> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      _codeCtrl.text = result;
      _join();
    }
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context)!;
    if (_codeCtrl.text.trim().isEmpty) {
      showErrorSnack(context, l10n.pleaseEnterInviteCode);
      return;
    }
    setState(() => _isLoading = true);

    final error = await ref
        .read(joinGroupProvider.notifier)
        .joinGroup(_codeCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      // ── Translate internal error codes to localized messages ──────
      if (error == 'INVALID_CODE') {
        showErrorSnack(context, l10n.invalidInviteCode);
      } else if (error.startsWith('ALREADY_MEMBER::')) {
        final groupName = error.split('::').last;
        showErrorSnack(context, l10n.alreadyMemberOf(groupName));
      } else {
        showErrorSnack(context, error);
      }
    } else {
      showSuccessSnack(context, l10n.youJoinedGroup);
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

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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

            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.primaryDark
                    : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),

            const SizedBox(height: 16),

            Text(l10n.joinAGroupTitle,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: headingColor,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(
                l10n.enterInviteCodeDesc,
                style: TextStyle(
                    fontSize: 13, color: AppColors.primary)),

            const SizedBox(height: 24),

            // Code input
            TextFormField(
              controller: _codeCtrl,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.none,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: headingColor,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: 'a1b2c3d4',
                hintStyle: TextStyle(
                  fontSize: 20,
                  color: AppColors.primaryLight.withOpacity(0.4),
                  letterSpacing: 4,
                ),
                labelText: l10n.inviteCode,
                labelStyle:
                const TextStyle(color: AppColors.primary),
              ),
            ),

            const SizedBox(height: 28),

            SplitlyButton(
              label: l10n.joinGroup,
              isLoading: _isLoading,
              onPressed: _join,
              icon: Icons.login_rounded,
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanQrCode,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    color: AppColors.primary, size: 18),
                label: Text(l10n.scanQrCode,
                    style: const TextStyle(color: AppColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── QR Scanner Screen ─────────────────────────────────────────────────────────
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text(l10n.scanQrCode,
            style: const TextStyle(color: AppColors.primaryTint)),
        iconTheme: const IconThemeData(color: AppColors.primaryTint),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;
          final value = barcodes.first.rawValue;
          if (value == null || value.isEmpty) return;
          _handled = true;
          Navigator.pop(context, value);
        },
      ),
    );
  }
}