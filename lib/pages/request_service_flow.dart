// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:servicehponline/widgets/home_page_one.dart';
import 'package:servicehponline/widgets/home_page_two.dart';
import 'package:servicehponline/widgets/home_page_three.dart';

class RequestServiceFlow extends StatefulWidget {
  final String username;

  const RequestServiceFlow({Key? key, required this.username})
      : super(key: key);

  @override
  State<RequestServiceFlow> createState() => _RequestServiceFlowState();
}

class _RequestServiceFlowState extends State<RequestServiceFlow> {
  int _currentPage = 0;
  String _selectedDevice = '';
  String _selectedProblem = '';

  void _nextPage() {
    setState(() {
      if (_currentPage < 2) {
        _currentPage++;
      }
    });
  }

  void _prevPage() {
    setState(() {
      if (_currentPage > 0) {
        _currentPage--;
        if (_currentPage == 0) {
          _selectedDevice = '';
        }
      }
    });
  }

  void _onDeviceSelected(String device) {
    setState(() {
      _selectedDevice = device;
    });
  }

  void _onProblemSelected(String problem) {
    setState(() {
      _selectedProblem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentPage > 0) {
          _prevPage();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: _buildCurrentPage(),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 0:
        return HomePageOne(
          username: widget.username,
          onDeviceSelected: _onDeviceSelected,
          nextPage: _nextPage,
          prevPage: () {},
        );
      case 1:
        return HomePageTwo(
          selectedDevice: _selectedDevice,
          onProblemSelected: _onProblemSelected,
          prevPage: _prevPage,
          nextPage: _nextPage,
        );
      case 2:
        return HomePageThree(
          selectedDevice: _selectedDevice,
          selectedProblem: _selectedProblem,
          prevPage: () {},
        );
      default:
        return HomePageOne(
          username: widget.username,
          onDeviceSelected: _onDeviceSelected,
          nextPage: _nextPage,
          prevPage: () {},
        );
    }
  }
}
