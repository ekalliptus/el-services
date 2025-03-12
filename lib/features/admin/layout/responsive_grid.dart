import 'package:flutter/material.dart';

/// Sistem grid responsif untuk Admin Dashboard
///
/// Kelas ini menyediakan widget dan utilitas untuk membangun tata letak
/// responsif sesuai dengan ukuran layar yang berbeda.
class ResponsiveGrid {
  // Breakpoint dalam pixel
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopSmallBreakpoint = 1200;

  /// Mendapatkan jumlah kolom berdasarkan lebar layar
  static int getColumnCount(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    if (width < mobileBreakpoint) {
      return 4; // Mobile - 4 kolom
    } else if (width < tabletBreakpoint) {
      return 8; // Tablet - 8 kolom
    } else if (width < desktopSmallBreakpoint) {
      return 12; // Desktop Kecil - 12 kolom
    } else {
      return 16; // Desktop Besar - 16 kolom
    }
  }

  /// Mengecek apakah perangkat adalah mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Mengecek apakah perangkat adalah tablet
  static bool isTablet(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Mengecek apakah perangkat adalah desktop kecil
  static bool isSmallDesktop(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < desktopSmallBreakpoint;
  }

  /// Mengecek apakah perangkat adalah desktop besar
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopSmallBreakpoint;
  }

  /// Mengecek apakah orientasi adalah landscape
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Mendapatkan lebar untuk ukuran kolom tertentu
  static double getColumnWidth(BuildContext context, int span) {
    final int totalColumns = getColumnCount(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double padding = isMobile(context) ? 16 : 24;
    final double availableWidth = screenWidth - (padding * 2);

    // Batasi span ke jumlah kolom maksimal
    final int safeSpan = span > totalColumns ? totalColumns : span;

    return (availableWidth / totalColumns) * safeSpan;
  }
}

/// Widget yang menyediakan kontainer responsif dengan lebar yang sesuai dengan grid
class ResponsiveGridContainer extends StatelessWidget {
  final Widget child;
  final int mobileSpan;
  final int tabletSpan;
  final int desktopSmallSpan;
  final int desktopLargeSpan;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Alignment alignment;

  const ResponsiveGridContainer({
    Key? key,
    required this.child,
    this.mobileSpan = 4,
    this.tabletSpan = 8,
    this.desktopSmallSpan = 10,
    this.desktopLargeSpan = 12,
    this.height,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.color,
    this.alignment = Alignment.topLeft,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int span = mobileSpan;

    if (ResponsiveGrid.isLargeDesktop(context)) {
      span = desktopLargeSpan;
    } else if (ResponsiveGrid.isSmallDesktop(context)) {
      span = desktopSmallSpan;
    } else if (ResponsiveGrid.isTablet(context)) {
      span = tabletSpan;
    }

    return Container(
      width: ResponsiveGrid.getColumnWidth(context, span),
      height: height,
      padding: padding,
      margin: margin,
      color: color,
      alignment: alignment,
      child: child,
    );
  }
}

/// Widget yang menyediakan baris responsif dengan kolom yang sejajar secara horizontal
class ResponsiveGridRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final EdgeInsetsGeometry padding;
  final bool autoWrap;

  const ResponsiveGridRow({
    Key? key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.padding = EdgeInsets.zero,
    this.autoWrap = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: autoWrap
          ? Wrap(
              alignment: _convertMainAxisAlignmentToWrapAlignment(),
              crossAxisAlignment:
                  _convertCrossAxisAlignmentToWrapCrossAlignment(),
              children: children,
            )
          : Row(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: mainAxisSize,
              children: children,
            ),
    );
  }

  WrapAlignment _convertMainAxisAlignmentToWrapAlignment() {
    switch (mainAxisAlignment) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.end:
        return WrapAlignment.end;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return WrapAlignment.spaceEvenly;
      }
  }

  WrapCrossAlignment _convertCrossAxisAlignmentToWrapCrossAlignment() {
    switch (crossAxisAlignment) {
      case CrossAxisAlignment.start:
        return WrapCrossAlignment.start;
      case CrossAxisAlignment.end:
        return WrapCrossAlignment.end;
      case CrossAxisAlignment.center:
        return WrapCrossAlignment.center;
      case CrossAxisAlignment.stretch:
      case CrossAxisAlignment.baseline:
      return WrapCrossAlignment.start;
    }
  }
}

/// Widget responsif yang menampilkan konten berbeda berdasarkan ukuran layar
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext)? mobileBuilder;
  final Widget Function(BuildContext)? tabletBuilder;
  final Widget Function(BuildContext)? desktopSmallBuilder;
  final Widget Function(BuildContext)? desktopLargeBuilder;
  final Widget Function(BuildContext)? defaultBuilder;

  const ResponsiveBuilder({
    Key? key,
    this.mobileBuilder,
    this.tabletBuilder,
    this.desktopSmallBuilder,
    this.desktopLargeBuilder,
    this.defaultBuilder,
  })  : assert(
            mobileBuilder != null ||
                tabletBuilder != null ||
                desktopSmallBuilder != null ||
                desktopLargeBuilder != null ||
                defaultBuilder != null,
            'Minimal salah satu builder harus disediakan'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ResponsiveGrid.isMobile(context) && mobileBuilder != null) {
      return mobileBuilder!(context);
    } else if (ResponsiveGrid.isTablet(context) && tabletBuilder != null) {
      return tabletBuilder!(context);
    } else if (ResponsiveGrid.isSmallDesktop(context) &&
        desktopSmallBuilder != null) {
      return desktopSmallBuilder!(context);
    } else if (ResponsiveGrid.isLargeDesktop(context) &&
        desktopLargeBuilder != null) {
      return desktopLargeBuilder!(context);
    } else if (defaultBuilder != null) {
      return defaultBuilder!(context);
    }

    // Fallback ke builder yang tersedia
    if (mobileBuilder != null) {
      return mobileBuilder!(context);
    } else if (tabletBuilder != null) {
      return tabletBuilder!(context);
    } else if (desktopSmallBuilder != null) {
      return desktopSmallBuilder!(context);
    } else {
      return desktopLargeBuilder!(context);
    }
  }
}
