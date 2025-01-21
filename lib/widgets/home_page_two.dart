// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:servicehponline/models/device_problems.dart';
import 'package:servicehponline/widgets/page_indicator.dart';

class HomePageTwo extends StatelessWidget {
  final String selectedDevice;
  final Function(String) onProblemSelected;
  final VoidCallback prevPage;
  final VoidCallback nextPage;

  const HomePageTwo({
    Key? key,
    required this.selectedDevice,
    required this.onProblemSelected,
    required this.prevPage,
    required this.nextPage,
  }) : super(key: key);

  void _selectProblem(String problem) {
    onProblemSelected(problem);
    nextPage();
  }

  @override
  Widget build(BuildContext context) {
    final deviceProblems = DeviceProblems.problems[selectedDevice] ?? [];
    final problems =
        deviceProblems.expand((list) => list).expand((e) => [e]).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageIndicator(currentPage: 1, darkMode: false),
                    SizedBox(height: 20.0),
                    Text(
                      "Pilih Masalah",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12.0),
                    Text(
                      "Silakan pilih masalah yang dialami perangkat Anda",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16.0,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.0),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.all(16.0),
                    itemCount: problems.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: 16.0),
                    itemBuilder: (context, index) {
                      final problem = problems[index];
                      return _buildProblemButton(
                        context: context,
                        icon: problem.icon,
                        label: problem.name,
                        info: problem.info,
                        onTap: () => _selectProblem(problem.key),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProblemButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String info,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue,
                  size: 24.0,
                ),
              ),
              SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.0),
                    Text(
                      info,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.black54,
                size: 16.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
