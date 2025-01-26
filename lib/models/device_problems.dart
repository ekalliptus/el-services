import 'package:flutter/material.dart';
import 'package:servicehponline/models/m_android.dart';
import 'package:servicehponline/models/m_iphone.dart';
import 'package:servicehponline/models/m_huawei.dart';

class DeviceProblem {
  final String key;
  final String name;
  final String info;
  final IconData icon;

  const DeviceProblem({
    required this.key,
    required this.name,
    required this.info,
    required this.icon,
  });

  factory DeviceProblem.fromAndroid(AndroidProblem problem) {
    return DeviceProblem(
      key: problem.key,
      name: problem.name,
      info: problem.info,
      icon: problem.icon,
    );
  }

  factory DeviceProblem.fromIPhone(IPhoneProblem problem) {
    return DeviceProblem(
      key: problem.key,
      name: problem.name,
      info: problem.info,
      icon: problem.icon,
    );
  }

  factory DeviceProblem.fromHuawei(HuaweiProblem problem) {
    return DeviceProblem(
      key: problem.key,
      name: problem.name,
      info: problem.info,
      icon: problem.icon,
    );
  }
}

class DeviceProblems {
  static final Map<String, String> _deviceNames = {
    'android': 'Android',
    'iphone': 'iPhone',
    'huawei': 'Huawei',
  };

  static final Map<String, String> _problemNames = {
    // iPhone Problems
    'lcd_iphone': 'Masalah LCD iPhone',
    'battery_iphone': 'Masalah Baterai iPhone',
    'charging_iphone': 'Masalah Port Charging/Cas iPhone',
    'audio_iphone': 'Masalah Audio/Suara iPhone',
    'connectivity_iphone': 'Masalah Wifi/GPS/Bluetooth iPhone',
    'mati_total_iphone': 'Masalah Mati Total iPhone',
    'bootloop_iphone': 'Masalah Bootloop/Logo/Hang iPhone',
    'camera_iphone': 'Masalah Camera iPhone',
    'handfree_iphone': 'Masalah Handfree iPhone',
    'signal_iphone': 'Masalah Sinyal iPhone',
    'button_iphone': 'Masalah On Off, Tombol Volume iPhone',
    'simcard_iphone': 'Masalah Simcard iPhone',
    'casing_iphone': 'Masalah Casing iPhone',
    'ic_iphone': 'Masalah IC iPhone',
    'flexible_iphone': 'Masalah Fleksibel iPhone',
    'software_iphone': 'Masalah Software iPhone',
    'hardware_iphone': 'Masalah Hardware iPhone',
    'glass_iphone': 'Masalah Perbaikan Kaca LCD/Camera iPhone',
    'security_iphone': 'Masalah Face ID/Touch ID iPhone',
    'other_iphone': 'Masalah Kerusakan Lainnya iPhone',

    // Android Problems
    'lcd_android': 'Masalah LCD Android',
    'battery_android': 'Masalah Baterai Android',
    'charging_android': 'Masalah Port Charging/Cas Android',
    'audio_android': 'Masalah Audio/Suara Android',
    'connectivity_android': 'Masalah Wifi/GPS/Bluetooth Android',
    'mati_total_android': 'Masalah Mati Total Android',
    'bootloop_android': 'Masalah Bootloop/Logo/Hang Android',
    'camera_android': 'Masalah Camera Android',
    'handfree_android': 'Masalah Handfree Android',
    'signal_android': 'Masalah Sinyal Android',
    'button_android': 'Masalah On Off, Tombol Volume Android',
    'simcard_android': 'Masalah Simcard Android',
    'casing_android': 'Masalah Casing Android',
    'ic_android': 'Masalah IC Android',
    'flexible_android': 'Masalah Fleksibel Android',
    'software_android': 'Masalah Software Android',
    'hardware_android': 'Masalah Hardware Android',
    'glass_android': 'Masalah Perbaikan Kaca LCD/Camera Android',
    'security_android': 'Masalah Face ID/Touch ID Android',
    'other_android': 'Masalah Kerusakan Lainnya Android',

    // Huawei Problems
    'lcd_huawei': 'Masalah LCD Huawei',
    'battery_huawei': 'Masalah Baterai Huawei',
    'charging_huawei': 'Masalah Port Charging/Cas Huawei',
    'audio_huawei': 'Masalah Audio/Suara Huawei',
    'connectivity_huawei': 'Masalah Wifi/GPS/Bluetooth Huawei',
    'mati_total_huawei': 'Masalah Mati Total Huawei',
    'bootloop_huawei': 'Masalah Bootloop/Logo/Hang Huawei',
    'camera_huawei': 'Masalah Camera Huawei',
    'handfree_huawei': 'Masalah Handfree Huawei',
    'signal_huawei': 'Masalah Sinyal Huawei',
    'button_huawei': 'Masalah On Off, Tombol Volume Huawei',
    'simcard_huawei': 'Masalah Simcard Huawei',
    'casing_huawei': 'Masalah Casing Huawei',
    'ic_huawei': 'Masalah IC Huawei',
    'flexible_huawei': 'Masalah Fleksibel Huawei',
    'software_huawei': 'Masalah Software Huawei',
    'hardware_huawei': 'Masalah Hardware Huawei',
    'glass_huawei': 'Masalah Perbaikan Kaca LCD/Camera Huawei',
    'security_huawei': 'Masalah Face ID/Fingerprint Huawei',
    'other_huawei': 'Masalah Kerusakan Lainnya Huawei',
  };

  static String getDeviceName(String key) {
    return _deviceNames[key.toLowerCase()] ?? key;
  }

  static String getProblemName(String key) {
    final problemKey = key.toLowerCase();
    return _problemNames[problemKey] ??
        IPhoneProblems.problems
            .expand((list) => list)
            .firstWhere(
              (problem) => problem.key.toLowerCase() == problemKey,
              orElse: () => IPhoneProblem(
                key: problemKey,
                name: key,
                info: '',
                icon: Icons.error,
              ),
            )
            .name;
  }

  static final Map<String, List<List<DeviceProblem>>> problems = {
    'iphone': IPhoneProblems.problems
        .map((list) =>
            list.map((problem) => DeviceProblem.fromIPhone(problem)).toList())
        .toList(),
    'android': AndroidProblems.problems
        .map((list) =>
            list.map((problem) => DeviceProblem.fromAndroid(problem)).toList())
        .toList(),
    'huawei': HuaweiProblems.problems
        .map((list) =>
            list.map((problem) => DeviceProblem.fromHuawei(problem)).toList())
        .toList(),
  };
}
