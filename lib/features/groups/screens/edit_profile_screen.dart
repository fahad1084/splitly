import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase/supabase_config.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/groups_controller.dart';

const _avatarColors = [
  '#0F766E', '#134E4A', '#14B8A6',
  '#EAB308', '#CA8A04', '#16A34A',
  '#DC2626', '#7C3AED', '#0891B2',
];

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  String _selectedColor = '#0F766E';
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select('full_name, phone, avatar_color, avatar_url')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _nameCtrl.text = data['full_name'] as String? ?? '';
          _phoneCtrl.text = data['phone'] as String? ?? '';
          _selectedColor = data['avatar_color'] as String? ?? '#0F766E';
          _avatarUrl = data['avatar_url'] as String?;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1200,
    );
    if (picked == null) return;

    // Let the user crop to a centered square before uploading — avoids
    // off-center or wrong-aspect-ratio photos looking odd in the circle.
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 80,
      compressFormat: ImageCompressFormat.jpg,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: l10n.editProfileTitle,
          toolbarColor: AppColors.primaryDark,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: l10n.editProfileTitle,
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final ext = cropped.path.split('.').last;
      final path = '$userId/avatar.$ext';

      await SupabaseConfig.client.storage
          .from('avatars')
          .upload(path, File(cropped.path),
          fileOptions: const FileOptions(upsert: true));

      final url =
      SupabaseConfig.client.storage.from('avatars').getPublicUrl(path);
      final bustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      await SupabaseConfig.client
          .from('profiles')
          .update({'avatar_url': bustedUrl}).eq('id', userId);

      if (mounted) {
        setState(() => _avatarUrl = bustedUrl);
        // Refresh anywhere else this avatar is shown — profile tab and
        // every group's member list — since they cache their own data.
        ref.invalidate(myProfileProvider);
        ref.invalidate(groupMembersProvider);
      }
    } catch (e) {
      print('=== AVATAR UPLOAD ERROR: $e ===');
      if (mounted) showErrorSnack(context, l10n.failedToUpdatePhoto);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseConfig.client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        'avatar_color': _selectedColor,
      }).eq('id', userId);

      // Also update auth metadata so full_name shows correctly everywhere
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(data: {'full_name': _nameCtrl.text.trim()}),
      );

      if (!mounted) return;
      showSuccessSnack(context, l10n.profileUpdated);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, l10n.profileUpdateFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = isDark(context);
    final textColor = dark ? AppColors.primaryTint : AppColors.primaryDark;
    final email = SupabaseConfig.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.editProfileTitle)),
      body: _loadingProfile
          ? const Center(
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      )
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar preview ──────────────────────────────
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _parseColor(_selectedColor),
                          shape: BoxShape.circle,
                          image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? DecorationImage(
                            image: NetworkImage(_avatarUrl!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? Center(
                          child: Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w500,
                                color: Colors.white),
                          ),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: GestureDetector(
                          onTap: _isUploadingAvatar
                              ? null
                              : _pickAndUploadAvatar,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                  Theme.of(context).scaffoldBackgroundColor,
                                  width: 2),
                            ),
                            child: _isUploadingAvatar
                                ? const Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryDark),
                            )
                                : const Icon(Icons.camera_alt_rounded,
                                size: 14, color: AppColors.primaryDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Full name ────────────────────────────────────
                SplitlyTextField(
                  controller: _nameCtrl,
                  label: l10n.fullNameLabel,
                  hint: 'Ahmed Khan',
                  prefixIcon: Icons.person_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.nameRequired;
                    }
                    if (v.trim().length < 2) return l10n.nameTooShort;
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 14),

                // ── Email (read-only) ────────────────────────────
                TextFormField(
                  initialValue: email,
                  readOnly: true,
                  style: TextStyle(color: textColor.withOpacity(0.5)),
                  decoration: InputDecoration(
                    labelText: l10n.yourEmail,
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: dark
                        ? AppColors.primaryDark.withOpacity(0.3)
                        : AppColors.primaryTint.withOpacity(0.3),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Phone ─────────────────────────────────────────
                SplitlyTextField(
                  controller: _phoneCtrl,
                  label: l10n.phoneOptional,
                  hint: '+92 300 1234567',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 20),

                // ── Avatar color picker (only shown when no photo set) ──
                if (_avatarUrl == null || _avatarUrl!.isEmpty) ...[
                  Text(l10n.chooseAvatarColor,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textColor)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _avatarColors.map((hex) {
                      final selected = _selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _parseColor(hex),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                color: AppColors.accent, width: 3)
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ] else
                  const SizedBox(height: 12),

                SplitlyButton(
                  label: l10n.saveChanges,
                  isLoading: _isLoading,
                  onPressed: _save,
                  icon: Icons.check_rounded,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}