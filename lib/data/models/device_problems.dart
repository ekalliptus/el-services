import 'package:flutter/material.dart';
import 'package:servicehponline/data/models/devices/m_android.dart';
import 'package:servicehponline/data/models/devices/m_iphone.dart';
import 'package:servicehponline/data/models/devices/m_huawei.dart';

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
    // Common Problems
    'lcd': 'LCD Rusak/Pecah',
    'battery': 'Baterai Cepat Habis',
    'charging': 'Masalah Pengisian',
    'camera': 'Kamera Bermasalah',
    'speaker': 'Speaker/Suara',
    'button': 'Tombol Rusak',
    'water': 'Kemasukan Air',
    'software': 'Masalah Software',
    'face_id': 'Face ID Bermasalah',
    'touch_id': 'Touch ID Bermasalah',
    'icloud': 'iCloud Terkunci',
    'fingerprint': 'Fingerprint Bermasalah',
    'google_services': 'Google Services Error',
    'signal': 'Sinyal/Jaringan',
    'other': 'Lainnya',

    //iPhone Problems
    'lcd_iphone': 'iPhone - Masalah LCD',
    'battery_iphone': 'iPhone - Masalah Baterai',
    'charging_iphone': 'iPhone - Masalah Port Charging/Cas',
    'audio_iphone': 'iPhone - Masalah Audio/Suara',
    'connectivity_iphone': 'iPhone - Masalah Wifi/GPS/Bluetooth',
    'mati_total_iphone': 'iPhone - Masalah Mati Total',
    'bootloop_iphone': 'iPhone - Masalah Bootloop/Logo/Hang',
    'camera_iphone': 'iPhone - Masalah Camera',
    'handfree_iphone': 'iPhone - Masalah Handfree',
    'signal_iphone': 'iPhone - Masalah Sinyal',
    'button_iphone': 'iPhone - Masalah On Off, Tombol Volume',
    'simcard_iphone': 'iPhone - Masalah Simcard',
    'casing_iphone': 'iPhone - Masalah Casing',
    'ic_iphone': 'iPhone - Masalah IC',
    'flexible_iphone': 'iPhone - Masalah Fleksibel',
    'software_iphone': 'iPhone - Masalah Software',
    'hardware_iphone': 'iPhone - Masalah Hardware',
    'glass_iphone': 'iPhone - Masalah Perbaikan Kaca LCD/Camera',
    'security_iphone': 'iPhone - Masalah Face ID/Touch ID',
    'other_iphone': 'iPhone - Masalah Kerusakan Lainnya',

    // Android Problems
    'lcd_android': 'Android - Masalah LCD',
    'battery_android': 'Android - Masalah Baterai',
    'charging_android': 'Android - Masalah Port Charging/Cas',
    'audio_android': 'Android - Masalah Audio/Suara',
    'connectivity_android': 'Android - Masalah Wifi/GPS/Bluetooth',
    'mati_total_android': 'Android - Masalah Mati Total',
    'bootloop_android': 'Android - Masalah Bootloop/Logo/Hang',
    'camera_android': 'Android - Masalah Camera',
    'handfree_android': 'Android - Masalah Handfree',
    'signal_android': 'Android - Masalah Sinyal',
    'button_android': 'Android - Masalah On Off, Tombol Volume',
    'simcard_android': 'Android - Masalah Simcard',
    'casing_android': 'Android - Masalah Casing',
    'ic_android': 'Android - Masalah IC',
    'flexible_android': 'Android - Masalah Fleksibel',
    'software_android': 'Android - Masalah Software',
    'hardware_android': 'Android - Masalah Hardware',
    'glass_android': 'Android - Masalah Perbaikan Kaca LCD/Camera',
    'security_android': 'Android - Masalah Face ID/Touch ID',
    'other_android': 'Android - Masalah Kerusakan Lainnya',

    // Huawei Problems
    'lcd_huawei': 'Huawei - Masalah LCD',
    'battery_huawei': 'Huawei - Masalah Baterai',
    'charging_huawei': 'Huawei - Masalah Port Charging/Cas',
    'audio_huawei': 'Huawei - Masalah Audio/Suara',
    'connectivity_huawei': 'Huawei - Masalah Wifi/GPS/Bluetooth',
    'mati_total_huawei': 'Huawei - Masalah Mati Total',
    'bootloop_huawei': 'Huawei - Masalah Bootloop/Logo/Hang',
    'camera_huawei': 'Huawei - Masalah Camera',
    'handfree_huawei': 'Huawei - Masalah Handfree',
    'signal_huawei': 'Huawei - Masalah Sinyal',
    'button_huawei': 'Huawei - Masalah On Off, Tombol Volume',
    'simcard_huawei': 'Huawei - Masalah Simcard',
    'casing_huawei': 'Huawei - Masalah Casing',
    'ic_huawei': 'Huawei - Masalah IC',
    'flexible_huawei': 'Huawei - Masalah Fleksibel',
    'software_huawei': 'Huawei - Masalah Software',
    'hardware_huawei': 'Huawei - Masalah Hardware',
    'glass_huawei': 'Huawei - Masalah Perbaikan Kaca LCD/Camera',
    'security_huawei': 'Huawei - Masalah Face ID/Fingerprint',
    'other_huawei': 'Huawei - Masalah Kerusakan Lainnya',
  };

  static String formatDeviceName(Map<String, dynamic> data) {
    final device = data['device']?.toString() ?? '';
    final brand = data['brand']?.toString() ?? '';
    final model = data['model']?.toString() ?? '';

    if (brand.isNotEmpty) {
      return '$brand ${model.isNotEmpty ? '- $model' : ''}';
    } else {
      return device.isNotEmpty
          ? device[0].toUpperCase() + device.substring(1)
          : 'Unknown Device';
    }
  }

  static String getDeviceName(String key) {
    return _deviceNames[key.toLowerCase()] ?? key;
  }

  static String getProblemName(String key) {
    final problemKey = key.toLowerCase();
    return _problemNames[problemKey] ?? key;
  }

  static List<String> getProblems(String deviceType) {
    final commonProblems = [
      'lcd',
      'battery',
      'charging',
      'camera',
      'speaker',
      'button',
      'water',
      'software',
      'other',
    ];

    switch (deviceType) {
      case 'iphone':
        return [
          ...commonProblems,
          'face_id',
          'touch_id',
          'icloud',
        ];
      case 'huawei':
        return [
          ...commonProblems,
          'fingerprint',
          'google_services',
        ];
      default: // android
        return [
          ...commonProblems,
          'fingerprint',
          'signal',
        ];
    }
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
