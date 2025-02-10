import 'package:flutter/material.dart';

class AndroidProblem {
  final String key;
  final String name;
  final String info;
  final IconData icon;

  const AndroidProblem({
    required this.key,
    required this.name,
    required this.info,
    required this.icon,
  });
}

class AndroidProblems {
  static final List<List<AndroidProblem>> problems = [
    [
      AndroidProblem(
        key: 'lcd_android',
        name: 'Masalah LCD',
        info: 'LCD retak, bergaris, atau mati total',
        icon: Icons.phone_android,
      ),
      AndroidProblem(
        key: 'battery_android',
        name: 'Masalah Baterai',
        info: 'Baterai cepat habis, tidak bisa mengisi, atau mengembung',
        icon: Icons.battery_alert,
      ),
    ],
    [
      AndroidProblem(
        key: 'charging_android',
        name: 'Masalah Port Charging/Cas',
        info: 'Tidak bisa mengisi daya, charging lambat atau tidak stabil',
        icon: Icons.charging_station,
      ),
      AndroidProblem(
        key: 'audio_android',
        name: 'Masalah Audio/Suara',
        info: 'Speaker tidak bunyi, suara kecil, atau noise',
        icon: Icons.volume_up,
      ),
    ],
    [
      AndroidProblem(
        key: 'connectivity_android',
        name: 'Masalah Wifi/GPS/Bluetooth',
        info: 'Koneksi tidak stabil atau tidak berfungsi',
        icon: Icons.wifi,
      ),
      AndroidProblem(
        key: 'mati_total_android',
        name: 'Masalah Mati Total',
        info: 'Perangkat tidak bisa dinyalakan sama sekali',
        icon: Icons.power_off,
      ),
    ],
    [
      AndroidProblem(
        key: 'bootloop_android',
        name: 'Masalah Bootloop/Logo/Hang',
        info: 'Restart terus menerus atau terjebak di logo',
        icon: Icons.refresh,
      ),
      AndroidProblem(
        key: 'camera_android',
        name: 'Masalah Camera',
        info: 'Kamera tidak berfungsi atau hasil foto blur',
        icon: Icons.camera_alt,
      ),
    ],
    [
      AndroidProblem(
        key: 'handfree_android',
        name: 'Masalah Handfree',
        info: 'Port audio tidak berfungsi atau suara tidak keluar di headset',
        icon: Icons.headphones,
      ),
      AndroidProblem(
        key: 'signal_android',
        name: 'Masalah Sinyal',
        info: 'Sinyal lemah atau tidak ada sinyal',
        icon: Icons.signal_cellular_alt,
      ),
    ],
    [
      AndroidProblem(
        key: 'button_android',
        name: 'Masalah On Off, Tombol Volume',
        info: 'Tombol tidak berfungsi atau macet',
        icon: Icons.power_settings_new,
      ),
      AndroidProblem(
        key: 'simcard_android',
        name: 'Masalah Simcard',
        info: 'Sim card tidak terbaca atau error',
        icon: Icons.sim_card,
      ),
    ],
    [
      AndroidProblem(
        key: 'casing_android',
        name: 'Masalah Casing',
        info: 'Casing rusak, lepas, atau perlu penggantian',
        icon: Icons.phone_android,
      ),
      AndroidProblem(
        key: 'ic_android',
        name: 'Masalah IC',
        info: 'Kerusakan pada IC atau komponen internal',
        icon: Icons.memory,
      ),
    ],
    [
      AndroidProblem(
        key: 'flexible_android',
        name: 'Masalah Fleksibel',
        info: 'Kerusakan pada kabel fleksibel atau konektor',
        icon: Icons.cable,
      ),
      AndroidProblem(
        key: 'software_android',
        name: 'Masalah Software',
        info: 'Error sistem, aplikasi crash, atau perlu update',
        icon: Icons.system_update,
      ),
    ],
    [
      AndroidProblem(
        key: 'hardware_android',
        name: 'Masalah Hardware',
        info: 'Kerusakan pada komponen fisik perangkat',
        icon: Icons.build,
      ),
      AndroidProblem(
        key: 'glass_android',
        name: 'Masalah Perbaikan Kaca LCD/Camera',
        info: 'Kaca pelindung retak atau perlu penggantian',
        icon: Icons.broken_image,
      ),
    ],
    [
      AndroidProblem(
        key: 'security_android',
        name: 'Masalah Face ID/Touch ID',
        info: 'Fingerprint atau face recognition tidak berfungsi',
        icon: Icons.fingerprint,
      ),
      AndroidProblem(
        key: 'other_android',
        name: 'Masalah Kerusakan Lainnya',
        info: 'Kerusakan lain yang belum tercantum',
        icon: Icons.help_outline,
      ),
    ],
  ];
}
