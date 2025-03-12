import 'package:flutter/material.dart';

/// Kelas utilitas untuk sistem grid responsif di dashboard admin
class ResponsiveGrid {
  /// Breakpoint untuk perangkat mobile
  static const double mobileBreakpoint = 600;

  /// Breakpoint untuk perangkat tablet
  static const double tabletBreakpoint = 900;

  /// Breakpoint untuk desktop kecil
  static const double smallDesktopBreakpoint = 1200;

  /// Breakpoint untuk desktop besar
  static const double largeDesktopBreakpoint = 1800;

  /// Mendapatkan jumlah kolom berdasarkan lebar layar
  static int getColumns(double width) {
    if (width < mobileBreakpoint) {
      return 4; // Mobile: 4 kolom
    } else if (width < tabletBreakpoint) {
      return 8; // Tablet: 8 kolom
    } else if (width < smallDesktopBreakpoint) {
      return 12; // Desktop kecil: 12 kolom
    } else {
      return 16; // Desktop besar: 16 kolom
    }
  }

  /// Mendapatkan gutter (jarak antar komponen) berdasarkan lebar layar
  static double getGutter(double width) {
    if (width < mobileBreakpoint) {
      return 8.0; // Mobile: gutter kecil
    } else if (width < tabletBreakpoint) {
      return 16.0; // Tablet: gutter medium
    } else {
      return 24.0; // Desktop: gutter besar
    }
  }

  /// Mendapatkan padding layar berdasarkan lebar layar
  static EdgeInsets getScreenPadding(double width) {
    if (width < mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0);
    }
  }

  /// Mendapatkan lebar maksimum konten berdasarkan lebar layar
  static double getMaxContentWidth(double width) {
    if (width < smallDesktopBreakpoint) {
      return width; // Gunakan lebar penuh untuk mobile/tablet
    } else {
      return 1200.0; // Batasi lebar konten untuk desktop
    }
  }

  /// Menentukan apakah layar termasuk mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Menentukan apakah layar termasuk tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Menentukan apakah layar termasuk desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
}

/// Widget grid yang responsif
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final int? overrideColumns;
  final double? overrideItemHeight;
  final double aspectRatio;
  final EdgeInsets? padding;

  const ResponsiveGridView({
    Key? key,
    required this.children,
    this.overrideColumns,
    this.overrideItemHeight,
    this.aspectRatio = 1.0,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = overrideColumns ?? _getColumnsForWidth(width);
        final gutter = ResponsiveGrid.getGutter(width);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: padding ?? EdgeInsets.all(gutter),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gutter,
            mainAxisSpacing: gutter,
            childAspectRatio: aspectRatio,
            mainAxisExtent: overrideItemHeight,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  int _getColumnsForWidth(double width) {
    if (width < ResponsiveGrid.mobileBreakpoint) {
      return 2; // 2 kolom untuk mobile
    } else if (width < ResponsiveGrid.tabletBreakpoint) {
      return 3; // 3 kolom untuk tablet
    } else if (width < ResponsiveGrid.smallDesktopBreakpoint) {
      return 4; // 4 kolom untuk desktop kecil
    } else {
      return 6; // 6 kolom untuk desktop besar
    }
  }
}
