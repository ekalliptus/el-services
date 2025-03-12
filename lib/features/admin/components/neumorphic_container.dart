import 'package:flutter/material.dart';
import '../theme/admin_design_tokens.dart';

/// Komponen Neumorphic
///
/// Widget ini menyediakan tampilan soft-UI dengan bayangan yang memberi kesan
/// tiga dimensi pada elemen UI flat.
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final bool pressed;
  final Color? backgroundColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final AlignmentGeometry alignment;

  const NeumorphicContainer({
    Key? key,
    required this.child,
    this.pressed = false,
    this.backgroundColor,
    this.radius = AdminDesignTokens.radiusMd,
    this.padding = const EdgeInsets.all(16.0),
    this.width,
    this.height,
    this.onTap,
    this.border,
    this.alignment = Alignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        backgroundColor ?? Theme.of(context).colorScheme.surface;

    // Warna bayangan untuk efek terang dan gelap
    final Color lightShadowColor =
        Colors.white.withOpacity(pressed ? 0.5 : 0.8);
    final Color darkShadowColor = Colors.black.withOpacity(pressed ? 0.2 : 0.1);

    // Offset untuk bayangan (berubah saat pressed)
    final Offset lightOffset = pressed ? Offset(1, 1) : Offset(-2, -2);
    final Offset darkOffset = pressed ? Offset(-1, -1) : Offset(2, 2);

    final Container container = Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: [
          // Bayangan terang
          BoxShadow(
            color: lightShadowColor,
            offset: lightOffset,
            blurRadius: pressed ? 2 : 4,
            spreadRadius: pressed ? 1 : 0,
          ),
          // Bayangan gelap
          BoxShadow(
            color: darkShadowColor,
            offset: darkOffset,
            blurRadius: pressed ? 2 : 4,
            spreadRadius: pressed ? 1 : 0,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}

/// Container Neumorphic yang dapat dipakai sebagai tombol
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Duration pressDuration;

  const NeumorphicButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.radius = AdminDesignTokens.radiusSm,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AdminDesignTokens.spacingMd,
      vertical: AdminDesignTokens.spacingSm,
    ),
    this.pressDuration = const Duration(milliseconds: 150),
  }) : super(key: key);

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: widget.pressDuration,
        child: NeumorphicContainer(
          pressed: _isPressed,
          backgroundColor: widget.backgroundColor,
          radius: widget.radius,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Tab Neumorphic untuk TabBar
class NeumorphicTab extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final EdgeInsetsGeometry padding;

  const NeumorphicTab({
    Key? key,
    required this.child,
    this.isSelected = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AdminDesignTokens.spacingMd,
      vertical: AdminDesignTokens.spacingSm,
    ),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      pressed: isSelected,
      padding: padding,
      radius: AdminDesignTokens.radiusSm,
      child: child,
    );
  }
}

/// Field input Neumorphic
class NeumorphicTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final int? maxLines;
  final int? minLines;

  const NeumorphicTextField({
    Key? key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeumorphicContainer(
      pressed: true,
      padding: EdgeInsets.zero,
      radius: AdminDesignTokens.radiusSm,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
            borderSide: BorderSide(
              color: theme.colorScheme.error,
              width: AdminDesignTokens.borderWidthXs,
            ),
          ),
          contentPadding: EdgeInsets.all(AdminDesignTokens.spacingMd),
          filled: true,
          fillColor: theme.colorScheme.surface,
        ),
        style: theme.textTheme.bodyMedium,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        enabled: enabled,
        maxLines: maxLines,
        minLines: minLines,
      ),
    );
  }
}
