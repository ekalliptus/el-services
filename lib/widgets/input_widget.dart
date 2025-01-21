import 'package:flutter/material.dart';

class InputWidget extends StatelessWidget {
  final String hintText;
  final IconData suffixIcon;
  final bool obscureText;
  final TextEditingController? controller;

  const InputWidget(
      {super.key,
      required this.suffixIcon,
      required this.hintText,
      this.obscureText = false,
      this.controller});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      height: 59.0,
      decoration: BoxDecoration(
        color: Color.fromRGBO(247, 247, 249, 1),
        borderRadius: BorderRadius.circular(32.0),
      ),
      padding: EdgeInsets.only(
        right: 24.0,
        left: 24.0,
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          suffixIcon: Icon(
            suffixIcon,
            color: Color.fromRGBO(105, 108, 121, 1),
          ),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.transparent,
            ),
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14.0,
            color: Color.fromRGBO(124, 124, 124, 1),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
