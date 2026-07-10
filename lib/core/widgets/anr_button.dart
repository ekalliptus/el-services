import 'package:flutter/material.dart';

enum AnrButtonVariant { primary, secondary, ghost }

/// Tombol ANRServices konsisten. Mengandalkan tema (primary/outlined) +
/// varian ghost. Default full-width.
class AnrButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AnrButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  const AnrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AnrButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                variant == AnrButtonVariant.primary
                    ? scheme.onPrimary
                    : scheme.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final effectiveOnPressed = loading ? null : onPressed;
    final Widget button = switch (variant) {
      AnrButtonVariant.primary =>
        ElevatedButton(onPressed: effectiveOnPressed, child: child),
      AnrButtonVariant.secondary =>
        OutlinedButton(onPressed: effectiveOnPressed, child: child),
      AnrButtonVariant.ghost => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          child: child,
        ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
