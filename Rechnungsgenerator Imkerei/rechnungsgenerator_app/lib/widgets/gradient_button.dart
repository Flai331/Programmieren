import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

/// Primär-Button mit Gradient (Gold → Orange), wie in der HTML-Referenz.
/// Varianten: primary (gradient), success (grün), danger (rot).
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final _ButtonVariant variant;
  final bool fullWidth;
  final double fontSize;

  const GradientButton({
    Key? key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = true,
    this.fontSize = 15,
  })  : variant = _ButtonVariant.primary,
        super(key: key);

  const GradientButton.success({
    Key? key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = true,
    this.fontSize = 15,
  })  : variant = _ButtonVariant.success,
        super(key: key);

  const GradientButton.danger({
    Key? key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = true,
    this.fontSize = 15,
  })  : variant = _ButtonVariant.danger,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    Widget button = AnimatedOpacity(
      opacity: isDisabled ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: _shadowColor.withAlpha(80),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: content,
        ),
      ),
    );

    return button;
  }

  LinearGradient get _gradient {
    switch (variant) {
      case _ButtonVariant.success:
        return const LinearGradient(
          colors: [Color(0xFF28a745), Color(0xFF218838)],
        );
      case _ButtonVariant.danger:
        return const LinearGradient(
          colors: [Color(0xFFdc3545), Color(0xFFc82333)],
        );
      case _ButtonVariant.primary:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppConstants.gradientStart, AppConstants.gradientEnd],
        );
    }
  }

  Color get _shadowColor {
    switch (variant) {
      case _ButtonVariant.success:
        return const Color(0xFF28a745);
      case _ButtonVariant.danger:
        return const Color(0xFFdc3545);
      case _ButtonVariant.primary:
        return AppConstants.gradientEnd;
    }
  }
}

enum _ButtonVariant { primary, success, danger }

/// Kleiner "Weiter →" Button (nur Text + Pfeil)
class NextTabButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const NextTabButton({
    Key? key,
    this.label = 'Weiter',
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GradientButton(
      label: '$label →',
      icon: null,
      onPressed: onPressed,
    );
  }
}
