import 'package:flutter/material.dart';

class Helper {
  static void nextPage(BuildContext context, String route,
      {Object? arguments}) {
    Navigator.pushReplacementNamed(
      context,
      route,
      arguments: arguments,
    );
  }
}
