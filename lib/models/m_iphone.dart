import 'package:flutter/material.dart';

class IPhoneProblem {
  final String key;
  final String name;
  final String info;
  final IconData icon;

  const IPhoneProblem({
    required this.key,
    required this.name,
    required this.info,
    required this.icon,
  });
}

class IPhoneProblems {
  static final List<List<IPhoneProblem>> problems = [
    [
      IPhoneProblem(
        key: 'lcd_iphone',
        name: 'Masalah LCD',
        info: 'LCD retak, bergaris, atau mati total',
        icon: Icons.phone_iphone,
      ),
      IPhoneProblem(
        key: 'battery_iphone',
        name: 'Masalah Baterai',
        info: 'Baterai cepat habis, tidak bisa mengisi, atau mengembung',
        icon: Icons.battery_alert,
      ),
    ],
    [
      IPhoneProblem(
        key: 'charging_iphone',
        name: 'Masalah Port Charging/Cas',
        info: 'Tidak bisa mengisi daya, charging lambat atau tidak stabil',
        icon: Icons.charging_station,
      ),
      IPhoneProblem(
        key: 'audio_iphone',
        name: 'Masalah Audio/Suara',
        info: 'Speaker tidak bunyi, suara kecil, atau noise',
        icon: Icons.volume_up,
      ),
    ],
    [
      IPhoneProblem(
        key: 'connectivity_iphone',
        name: 'Masalah Wifi/GPS/Bluetooth',
        info: 'Koneksi tidak stabil atau tidak berfungsi',
        icon: Icons.wifi,
      ),
      IPhoneProblem(
        key: 'mati_total_iphone',
        name: 'Masalah Mati Total',
        info: 'Perangkat tidak bisa dinyalakan sama sekali',
        icon: Icons.power_off,
      ),
    ],
    [
      IPhoneProblem(
        key: 'bootloop_iphone',
        name: 'Masalah Bootloop/Logo/Hang',
        info: 'Restart terus menerus atau terjebak di logo',
        icon: Icons.refresh,
      ),
      IPhoneProblem(
        key: 'camera_iphone',
        name: 'Masalah Camera',
        info: 'Kamera tidak berfungsi atau hasil foto blur',
        icon: Icons.camera_alt,
      ),
    ],
    [
      IPhoneProblem(
        key: 'handfree_iphone',
        name: 'Masalah Handfree',
        info: 'Port audio tidak berfungsi atau suara tidak keluar di headset',
        icon: Icons.headphones,
      ),
      IPhoneProblem(
        key: 'signal_iphone',
        name: 'Masalah Sinyal',
        info: 'Sinyal lemah atau tidak ada sinyal',
        icon: Icons.signal_cellular_alt,
      ),
    ],
    [
      IPhoneProblem(
        key: 'button_iphone',
        name: 'Masalah On Off, Tombol Volume',
        info: 'Tombol tidak berfungsi atau macet',
        icon: Icons.power_settings_new,
      ),
      IPhoneProblem(
        key: 'simcard_iphone',
        name: 'Masalah Simcard',
        info: 'Sim card tidak terbaca atau error',
        icon: Icons.sim_card,
      ),
    ],
    [
      IPhoneProblem(
        key: 'casing_iphone',
        name: 'Masalah Casing',
        info: 'Casing rusak, lepas, atau perlu penggantian',
        icon: Icons.phone_iphone,
      ),
      IPhoneProblem(
        key: 'ic_iphone',
        name: 'Masalah IC',
        info: 'Kerusakan pada IC atau komponen internal',
        icon: Icons.memory,
      ),
    ],
    [
      IPhoneProblem(
        key: 'flexible_iphone',
        name: 'Masalah Fleksibel',
        info: 'Kerusakan pada kabel fleksibel atau konektor',
        icon: Icons.cable,
      ),
      IPhoneProblem(
        key: 'software_iphone',
        name: 'Masalah Software',
        info: 'Error sistem, aplikasi crash, atau perlu update',
        icon: Icons.system_update,
      ),
    ],
    [
      IPhoneProblem(
        key: 'hardware_iphone',
        name: 'Masalah Hardware',
        info: 'Kerusakan pada komponen fisik perangkat',
        icon: Icons.build,
      ),
      IPhoneProblem(
        key: 'glass_iphone',
        name: 'Masalah Perbaikan Kaca LCD/Camera',
        info: 'Kaca pelindung retak atau perlu penggantian',
        icon: Icons.broken_image,
      ),
    ],
    [
      IPhoneProblem(
        key: 'security_iphone',
        name: 'Masalah Face ID/Touch ID',
        info: 'Fingerprint atau face recognition tidak berfungsi',
        icon: Icons.fingerprint,
      ),
      IPhoneProblem(
        key: 'other_iphone',
        name: 'Masalah Kerusakan Lainnya',
        info: 'Kerusakan lain yang belum tercantum',
        icon: Icons.help_outline,
      ),
    ],
  ];
}
