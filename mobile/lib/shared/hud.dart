import 'package:flutter/material.dart';
import 'package:vibe_studying_mobile/app/theme.dart';

class HudScaffold extends StatelessWidget {
  const HudScaffold({
    super.key,
    required this.child,
    this.title,
    this.actions,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              Color(0x33FF2EA6),
              Color(0x2200F5FF),
              AppPalette.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class HudPanel extends StatelessWidget {
  const HudPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.border),
        boxShadow: const [
          BoxShadow(color: Color(0x44FF2EA6), blurRadius: 24, spreadRadius: -8),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? AppPalette.neonPink : Colors.transparent;
    final foreground = isPrimary ? AppPalette.background : AppPalette.foreground;
    final borderColor = isPrimary ? AppPalette.neonPink : AppPalette.neonCyan;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class HudTag extends StatelessWidget {
  const HudTag({super.key, required this.label, this.color = AppPalette.neonCyan});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
