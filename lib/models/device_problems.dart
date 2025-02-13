class DeviceProblems {
  static String getProblemName(String key) {
    switch (key) {
      case 'lcd_broken':
        return 'LCD Rusak/Pecah';
      case 'water_damage':
        return 'Kemasukan Air';
      case 'not_charging':
        return 'Tidak Bisa Mengisi Daya';
      case 'battery_drain':
        return 'Baterai Cepat Habis';
      case 'camera_broken':
        return 'Kamera Rusak';
      case 'speaker_broken':
        return 'Speaker Rusak';
      case 'mic_broken':
        return 'Mikrofon Rusak';
      case 'button_broken':
        return 'Tombol Rusak';
      case 'wifi_broken':
        return 'WiFi Bermasalah';
      case 'signal_broken':
        return 'Sinyal Bermasalah';
      case 'bootloop':
        return 'Bootloop';
      case 'cant_turn_on':
        return 'Tidak Bisa Menyala';
      case 'software_problem':
        return 'Masalah Software';
      case 'other':
        return 'Lainnya';
      default:
        return key;
    }
  }
}
