import 'package:flutter/material.dart';
import 'anr_wordmark.dart';

/// Scaffold standar ANRServices: background mengikuti theme, app bar flat,
/// wordmark opsional, padding aman konsisten.
class AnrScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final bool showWordmark;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool safeArea;
  final EdgeInsetsGeometry padding;

  const AnrScaffold({
    super.key,
    required this.body,
    this.title,
    this.showWordmark = false,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeArea = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: body);
    if (safeArea) content = SafeArea(child: content);

    return Scaffold(
      appBar: (title != null || showWordmark || actions != null)
          ? AppBar(
              title: showWordmark
                  ? const AnrWordmark(fontSize: 22)
                  : title != null
                      ? Text(title!)
                      : null,
              actions: actions,
            )
          : null,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
