import 'package:flutter/material.dart';
import '../../config/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DARK MODE HELPER — use isDark(context) anywhere instead of repeating check
// ─────────────────────────────────────────────────────────────────────────────
bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// ─────────────────────────────────────────────────────────────────────────────
// S-BLOB LOGO PAINTER — brand SVG paths, teal+gold always look great on both
// ─────────────────────────────────────────────────────────────────────────────
class SBlobPainter extends CustomPainter {
  final Color tealColor;
  final Color goldColor;
  const SBlobPainter({
    this.tealColor = AppColors.primary,
    this.goldColor = AppColors.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 90, size.height / 90);
    canvas.drawPath(_tealPath(),
        Paint()..color = tealColor..style = PaintingStyle.fill);
    canvas.drawPath(_goldPath(),
        Paint()..color = goldColor..style = PaintingStyle.fill);
  }

  Path _tealPath() => Path()
    ..moveTo(45, 12)..cubicTo(27, 12, 15, 22, 15, 36)
    ..cubicTo(15, 48, 25, 54, 38, 56)..cubicTo(43, 57, 45, 61, 45, 66)
    ..cubicTo(45, 72, 38, 77, 29, 79)..cubicTo(39, 83, 54, 82, 63, 74)
    ..cubicTo(72, 66, 73, 54, 66, 44)..cubicTo(61, 37, 51, 35, 49, 28)
    ..cubicTo(47, 21, 52, 15, 62, 13)..cubicTo(57, 13, 51, 12, 45, 12)
    ..close();

  Path _goldPath() => Path()
    ..moveTo(45, 78)..cubicTo(63, 78, 75, 68, 75, 54)
    ..cubicTo(75, 42, 65, 36, 52, 34)..cubicTo(47, 33, 45, 29, 45, 24)
    ..cubicTo(45, 18, 52, 13, 62, 11)..cubicTo(52, 7, 37, 8, 28, 16)
    ..cubicTo(19, 24, 18, 36, 25, 46)..cubicTo(30, 53, 40, 55, 42, 62)
    ..cubicTo(44, 69, 39, 75, 29, 77)..cubicTo(33, 78, 39, 78, 45, 78)
    ..close();

  @override
  bool shouldRepaint(covariant SBlobPainter old) =>
      old.tealColor != tealColor || old.goldColor != goldColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// SPLITLY LOGO WIDGET — reads context, auto-adapts name/tagline color
// ─────────────────────────────────────────────────────────────────────────────
// Note: 'Splitly' and 'Your Circle. Your Hisaab.' are the brand name/tagline —
// these are never translated, same as how "WhatsApp" stays "WhatsApp" in any language.
class SplitlyLogo extends StatelessWidget {
  final double size;
  final bool showTagline;

  const SplitlyLogo({super.key, this.size = 64, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    final nameColor =
    isDark(context) ? AppColors.primaryTint : AppColors.primaryDark;
    final taglineColor =
    isDark(context) ? AppColors.accent : AppColors.accentDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CustomPaint(painter: SBlobPainter()),
        ),
        const SizedBox(height: 12),
        Text(
          'Splitly',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w500,
            color: nameColor,
            letterSpacing: -1,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 2),
          Text(
            'Your Circle. Your Hisaab.',
            style: TextStyle(
              fontSize: 12,
              color: taglineColor,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPLITLY TEXT FIELD — text/hint colors from Theme, icons always teal
// ─────────────────────────────────────────────────────────────────────────────
class SplitlyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final void Function(String)? onChanged; // ✅ added

  const SplitlyTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.autofillHints,
    this.onChanged, // ✅ added
  });

  @override
  State<SplitlyTextField> createState() => _SplitlyTextFieldState();
}

class _SplitlyTextFieldState extends State<SplitlyTextField> {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    // Fix: in dark mode onSurface renders too dark inside teal-tinted fields
    // Use explicit colors for both modes for maximum readability
    final textColor = isDark(context)
        ? AppColors.primaryTint       // bright mint-white in dark mode
        : AppColors.primaryDark;      // deep teal-dark in light mode
    final hintColor = isDark(context)
        ? AppColors.primaryLight.withOpacity(0.4)
        : AppColors.primaryLight.withOpacity(0.6);

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      autofocus: widget.autofocus,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged, // ✅ added
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 14),
        prefixIcon: Icon(widget.prefixIcon, color: AppColors.primary, size: 20),
        suffixIcon: widget.obscureText
            ? IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppColors.primaryLight,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        )
            : null,
      ),
      validator: widget.validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPLITLY BUTTON — brand colors work on both themes
// ─────────────────────────────────────────────────────────────────────────────
class SplitlyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutline;
  final IconData? icon;

  const SplitlyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutline = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
          strokeWidth: 2, color: Colors.white),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon,
              size: 18,
              color: isOutline ? AppColors.primary : Colors.white),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isOutline ? AppColors.primary : Colors.white,
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isOutline
          ? OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      )
          : ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SNACKBAR HELPERS — semantic colors, theme-independent
// ─────────────────────────────────────────────────────────────────────────────
void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
    ]),
    backgroundColor: AppColors.danger,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
  ));
}

void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
    ]),
    backgroundColor: AppColors.success,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE SIGN IN BUTTON — consistent full-width button for both screens
// Uses a clean SVG-painted Google G icon, no external asset needed
// ─────────────────────────────────────────────────────────────────────────────
class SplitlyGoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const SplitlyGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // ✅ added
    final dark = isDark(context);
    final bgColor = dark
        ? AppColors.primaryDark.withOpacity(0.6)
        : Colors.white;
    final borderColor =
    dark ? AppColors.primary.withOpacity(0.4) : AppColors.primaryTint;
    final textColor =
    dark ? AppColors.primaryTint : AppColors.primaryDark;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Google G icon painted in code
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(
                    painter: _GoogleGPainter(),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.continueWithGoogle, // ✅ localized
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Official Google G icon — drawn from Google's exact SVG path data
// Source: https://developers.google.com/identity/branding-guidelines
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Scale everything to fit our canvas size (original viewBox: 0 0 18 18)
    final scaleX = size.width / 18;
    final scaleY = size.height / 18;
    canvas.scale(scaleX, scaleY);

    final bluePaint   = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final redPaint    = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final greenPaint  = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;
    final whitePaint  = Paint()..color = Colors.white..style = PaintingStyle.fill;

    // ── Blue section (right half + crossbar) ─────────────────────────────
    final bluePath = Path()
      ..moveTo(17.64, 9.20)
      ..cubicTo(17.64, 8.57, 17.59, 7.96, 17.50, 7.38)
      ..lineTo(9.0, 7.38)
      ..lineTo(9.0, 10.85)
      ..lineTo(13.84, 10.85)
      ..cubicTo(13.64, 11.97, 13.00, 12.92, 12.05, 13.57)
      ..lineTo(12.05, 15.82)
      ..lineTo(14.96, 15.82)
      ..cubicTo(16.66, 14.25, 17.64, 11.93, 17.64, 9.20)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // ── Green section (bottom right) ──────────────────────────────────────
    final greenPath = Path()
      ..moveTo(9.0, 18.0)
      ..cubicTo(11.43, 18.0, 13.47, 17.19, 14.96, 15.82)
      ..lineTo(12.05, 13.57)
      ..cubicTo(11.23, 14.10, 10.21, 14.42, 9.0, 14.42)
      ..cubicTo(6.66, 14.42, 4.67, 12.84, 3.96, 10.71)
      ..lineTo(0.96, 10.71)
      ..lineTo(0.96, 13.03)
      ..cubicTo(2.44, 15.98, 5.48, 18.0, 9.0, 18.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // ── Yellow section (bottom left) ─────────────────────────────────────
    final yellowPath = Path()
      ..moveTo(3.96, 10.71)
      ..cubicTo(3.78, 10.18, 3.68, 9.60, 3.68, 9.0)
      ..cubicTo(3.68, 8.40, 3.78, 7.82, 3.96, 7.29)
      ..lineTo(3.96, 4.97)
      ..lineTo(0.96, 4.97)
      ..cubicTo(0.35, 6.17, 0.0, 7.55, 0.0, 9.0)
      ..cubicTo(0.0, 10.45, 0.35, 11.83, 0.96, 13.03)
      ..lineTo(3.96, 10.71)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // ── Red section (top left) ────────────────────────────────────────────
    final redPath = Path()
      ..moveTo(9.0, 3.58)
      ..cubicTo(10.32, 3.58, 11.51, 4.05, 12.44, 4.93)
      ..lineTo(15.02, 2.35)
      ..cubicTo(13.46, 0.89, 11.42, 0.0, 9.0, 0.0)
      ..cubicTo(5.48, 0.0, 2.44, 2.02, 0.96, 4.97)
      ..lineTo(3.96, 7.29)
      ..cubicTo(4.67, 5.16, 6.66, 3.58, 9.0, 3.58)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER LOADING CARD — reusable skeleton for lists while data loads
// ─────────────────────────────────────────────────────────────────────────────
class ShimmerCard extends StatelessWidget {
  final double height;
  final EdgeInsets margin;

  const ShimmerCard({
    super.key,
    this.height = 72,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final baseColor = dark ? AppColors.primaryDark : AppColors.primaryTint;
    final highlightColor = dark
        ? AppColors.primary.withOpacity(0.3)
        : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// List of shimmer cards — drop-in replacement for CircularProgressIndicator
class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
            (_) => const Padding(
          padding: EdgeInsets.only(top: 12),
          child: ShimmerCard(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH PAGE WRAPPER — scaffold + appbar fully theme-aware
// ─────────────────────────────────────────────────────────────────────────────
class AuthPageWrapper extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final String? title;

  const AuthPageWrapper({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Reads from ThemeData — lightBg in light, darkBg in dark
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    // Back button colors adapt per mode
    final backBtnBg =
    isDark(context) ? AppColors.primaryDark : AppColors.primaryTint;
    final backBtnIcon =
    isDark(context) ? AppColors.primaryTint : AppColors.primaryDark;

    // Title color adapts per mode
    final titleColor =
    isDark(context) ? AppColors.primaryTint : AppColors.primaryDark;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: showBackButton
          ? AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backBtnBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: backBtnIcon,
              size: 16,
            ),
          ),
        ),
        title: title != null
            ? Text(title!,
            style: TextStyle(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.w500))
            : null,
      )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }

}