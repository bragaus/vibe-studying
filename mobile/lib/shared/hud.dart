import 'package:flutter/material.dart';
import 'package:vibe_studying_mobile/app/theme.dart';

class HudScaffold extends StatelessWidget {
  const HudScaffold({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.collapsedLeading,
    this.actions,
    this.collapsedActions,
  });

  final Widget child;
  final String? title;
  final List<Widget>? leading;
  final List<Widget>? collapsedLeading;
  final List<Widget>? actions;
  final List<Widget>? collapsedActions;

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
                HudHeaderBar(
                  title: title!,
                  leading: leading,
                  collapsedLeading: collapsedLeading,
                  actions: actions,
                  collapsedActions: collapsedActions,
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class HudHeaderBar extends StatelessWidget {
  const HudHeaderBar({
    super.key,
    required this.title,
    this.leading,
    this.collapsedLeading,
    this.actions,
    this.collapsedActions,
  });

  final String title;
  final List<Widget>? leading;
  final List<Widget>? collapsedLeading;
  final List<Widget>? actions;
  final List<Widget>? collapsedActions;

  @override
  Widget build(BuildContext context) {
    final expandedLeading = leading ?? const <Widget>[];
    final compactLeading = collapsedLeading ?? expandedLeading;
    final expandedActions = actions ?? const <Widget>[];
    final compactActions = collapsedActions ?? expandedActions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showTitle = title.trim().isNotEmpty &&
              _hasRoomForTitle(
                context,
                maxWidth: constraints.maxWidth,
                leadingCount: expandedLeading.length,
                title: title,
                actionCount: expandedActions.length,
              );
          final headerLeading = showTitle ? expandedLeading : compactLeading;
          final headerActions = showTitle ? expandedActions : compactActions;
          final leadingSlotWidth =
              _estimateActionSlotWidth(headerLeading.length);
          final actionSlotWidth =
              _estimateActionSlotWidth(headerActions.length);
          final sideSlotWidth = leadingSlotWidth > actionSlotWidth
              ? leadingSlotWidth
              : actionSlotWidth;

          if (!showTitle) {
            return Row(
              children: [
                if (headerLeading.isNotEmpty)
                  _HeaderActionsRow(actions: headerLeading),
                const Spacer(),
                if (headerActions.isNotEmpty)
                  _HeaderActionsRow(actions: headerActions),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: sideSlotWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _HeaderActionsRow(actions: headerLeading),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SizedBox(
                width: sideSlotWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _HeaderActionsRow(actions: headerActions),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasRoomForTitle(
    BuildContext context, {
    required double maxWidth,
    required int leadingCount,
    required String title,
    required int actionCount,
  }) {
    final leadingWidth = _estimateActionSlotWidth(leadingCount);
    final actionWidth = _estimateActionSlotWidth(actionCount);
    final sideSlotWidth =
        leadingWidth > actionWidth ? leadingWidth : actionWidth;
    final availableTitleWidth = maxWidth - (sideSlotWidth * 2);
    if (availableTitleWidth <= 0) {
      return false;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    return textPainter.size.width <= availableTitleWidth;
  }

  double _estimateActionSlotWidth(int actionCount) {
    if (actionCount == 0) {
      return 0;
    }

    return (actionCount * 48.0) + ((actionCount - 1) * 8.0);
  }
}

class _HeaderActionsRow extends StatelessWidget {
  const _HeaderActionsRow({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          actions[index],
        ],
      ],
    );
  }
}

class HudPanel extends StatelessWidget {
  const HudPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18)});

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
    final foreground =
        isPrimary ? AppPalette.background : AppPalette.foreground;
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class HudTag extends StatelessWidget {
  const HudTag(
      {super.key, required this.label, this.color = AppPalette.neonCyan});

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
