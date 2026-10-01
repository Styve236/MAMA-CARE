import 'package:flutter/material.dart';

/// Tailles de reference utilisees pour les breakpoints.
class Breakpoints {
  static const double xs = 360.0;
  static const double sm = 600.0;
  static const double md = 900.0;
  static const double lg = 1200.0;

  static const double contentMax = 1180.0;
  static const double narrowMax = 700.0;

  /// En dessous de [sm] : telephone. En dessous de [md] : tablette.
  /// Au-dessus : ordinateur.
  static bool isMobile(double width) => width < sm;
  static bool isTablet(double width) => width >= sm && width < md;
  static bool isDesktop(double width) => width >= md;

  /// Nombre de colonnes adapte pour une grille de cartes.
  static int gridColumns(double width, {int min = 1, int max = 4}) {
    final int raw;
    if (width < xs) {
      raw = min;
    } else if (width < sm) {
      raw = min < 2 ? 2 : min;
    } else if (width < md) {
      raw = 2;
    } else if (width < lg) {
      raw = 3;
    } else {
      raw = 4;
    }
    return raw.clamp(1, max < 1 ? 1 : max);
  }
}

/// Extensions sur [BuildContext] pour eviter de repeter MediaQuery.
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  bool get isMobile => Breakpoints.isMobile(screenWidth);
  bool get isTablet => Breakpoints.isTablet(screenWidth);
  bool get isDesktop => Breakpoints.isDesktop(screenWidth);

  /// Padding horizontal adaptatif : plus serre sur telephone.
  EdgeInsets get pagePadding =>
      EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 24.0);

  /// Espacement vertical adaptatif.
  double get gap => isMobile ? 16.0 : 24.0;
}

/// Enveloppe de contenu : centre le contenu et borne sa largeur sur grand
/// ecran, sans jamais imposer de largeur minimale (donc sans overflow).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMax,
    this.padding,
    this.scrollable = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final inner = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? context.pagePadding,
          child: child,
        ),
      ),
    );
    if (!scrollable) return inner;
    return SingleChildScrollView(child: inner);
  }
}

/// Grille responsive : le nombre de colonnes suit la largeur disponible.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.maxColumns = 4,
    this.spacing = 16.0,
    this.runSpacing,
    this.childAspectRatio = 1.0,
  });

  final List<Widget> children;
  final int maxColumns;
  final double spacing;
  final double? runSpacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cols = Breakpoints.gridColumns(
          available,
          max: maxColumns,
        ).clamp(1, maxColumns);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing ?? spacing,
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}

/// Ligne responsive : empile verticalement sur petit ecran au lieu de
/// deborder horizontalement.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.stackBelow,
  });

  final List<Widget> children;
  final double spacing;

  /// Nombre d'enfants a garder sur la premiere ligne quand on n'a que la
  /// place d'une ligne complete (par defaut : tous).
  final int? stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = stackBelow ?? children.length;
        final keepInline = !context.isMobile || children.length <= stacked;
        if (keepInline) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              children[i],
            ],
          ],
        );
      },
    );
  }
}

/// Champ de texte qui ne provoque jamais d'overflow horizontal quand le
/// texte est long.
class FlexibleText extends StatelessWidget {
  const FlexibleText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: true,
    );
  }
}

/// Enveloppe de largeur bornee, pratique pour les cartes et panneaux.
class BoundedWidth extends StatelessWidget {
  const BoundedWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMax,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
