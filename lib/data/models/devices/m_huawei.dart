import 'package:flutter/material.dart';

class HuaweiProblem {
  final String key;
  final String name;
  final String info;
  final IconData icon;

  const HuaweiProblem({
    required this.key,
    required this.name,
    required this.info,
    required this.icon,
  });
}

class HuaweiProblems {
  static final List<List<HuaweiProblem>> problems = [
    [
      HuaweiProblem(
        key: 'lcd_huawei',
        name: 'Masalah LCD',
        info: 'LCD retak, bergaris, atau mati total',
        icon: Icons.phone_android,
      ),
      HuaweiProblem(
        key: 'battery_huawei',
        name: 'Masalah Baterai',
        info: 'Baterai cepat habis, tidak bisa mengisi, atau mengembung',
        icon: Icons.battery_alert,
      ),
    ],
    [
      HuaweiProblem(
        key: 'charging_huawei',
        name: 'Masalah Port Charging/Cas',
        info: 'Tidak bisa mengisi daya, charging lambat atau tidak stabil',
        icon: Icons.charging_station,
      ),
      HuaweiProblem(
        key: 'audio_huawei',
        name: 'Masalah Audio/Suara',
        info: 'Speaker tidak bunyi, suara kecil, atau noise',
        icon: Icons.volume_up,
      ),
    ],
    [
      HuaweiProblem(
        key: 'connectivity_huawei',
        name: 'Masalah Wifi/GPS/Bluetooth',
        info: 'Koneksi tidak stabil atau tidak berfungsi',
        icon: Icons.wifi,
      ),
      HuaweiProblem(
        key: 'mati_total_huawei',
        name: 'Masalah Mati Total',
        info: 'Perangkat tidak bisa dinyalakan sama sekali',
        icon: Icons.power_off,
      ),
    ],
    [
      HuaweiProblem(
        key: 'bootloop_huawei',
        name: 'Masalah Bootloop/Logo/Hang',
        info: 'Restart terus menerus atau terjebak di logo',
        icon: Icons.refresh,
      ),
      HuaweiProblem(
        key: 'camera_huawei',
        name: 'Masalah Camera',
        info: 'Kamera tidak berfungsi atau hasil foto blur',
        icon: Icons.camera_alt,
      ),
    ],
    [
      HuaweiProblem(
        key: 'handfree_huawei',
        name: 'Masalah Handfree',
        info: 'Port audio tidak berfungsi atau suara tidak keluar di headset',
        icon: Icons.headphones,
      ),
      HuaweiProblem(
        key: 'signal_huawei',
        name: 'Masalah Sinyal',
        info: 'Sinyal lemah atau tidak ada sinyal',
        icon: Icons.signal_cellular_alt,
      ),
    ],
    [
      HuaweiProblem(
        key: 'button_huawei',
        name: 'Masalah On Off, Tombol Volume',
        info: 'Tombol tidak berfungsi atau macet',
        icon: Icons.power_settings_new,
      ),
      HuaweiProblem(
        key: 'simcard_huawei',
        name: 'Masalah Simcard',
        info: 'Sim card tidak terbaca atau error',
        icon: Icons.sim_card,
      ),
    ],
    [
      HuaweiProblem(
        key: 'casing_huawei',
        name: 'Masalah Casing',
        info: 'Casing rusak, lepas, atau perlu penggantian',
        icon: Icons.phone_android,
      ),
      HuaweiProblem(
        key: 'ic_huawei',
        name: 'Masalah IC',
        info: 'Kerusakan pada IC atau komponen internal',
        icon: Icons.memory,
      ),
    ],
    [
      HuaweiProblem(
        key: 'flexible_huawei',
        name: 'Masalah Fleksibel',
        info: 'Kerusakan pada kabel fleksibel atau konektor',
        icon: Icons.cable,
      ),
      HuaweiProblem(
        key: 'software_huawei',
        name: 'Masalah Software',
        info: 'Error sistem, aplikasi crash, atau perlu update',
        icon: Icons.system_update,
      ),
    ],
    [
      HuaweiProblem(
        key: 'hardware_huawei',
        name: 'Masalah Hardware',
        info: 'Kerusakan pada komponen fisik perangkat',
        icon: Icons.build,
      ),
      HuaweiProblem(
        key: 'glass_huawei',
        name: 'Masalah Perbaikan Kaca LCD/Camera',
        info: 'Kaca pelindung retak atau perlu penggantian',
        icon: Icons.broken_image,
      ),
    ],
    [
      HuaweiProblem(
        key: 'security_huawei',
        name: 'Masalah Face ID/Fingerprint',
        info: 'Face recognition atau fingerprint tidak berfungsi',
        icon: Icons.fingerprint,
      ),
      HuaweiProblem(
        key: 'other_huawei',
        name: 'Masalah Kerusakan Lainnya',
        info: 'Kerusakan lain yang belum tercantum',
        icon: Icons.help_outline,
      ),
    ],
  ];
}
