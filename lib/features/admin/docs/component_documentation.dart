/// Dokumentasi Komponen Aplikasi Admin
/// File ini berisi dokumentasi dan panduan penggunaan komponen-komponen Admin Dashboard
/// Dokumentasi ini membantu memastikan konsistensi dan aksesibilitas.

/// # Panduan Penggunaan Komponen Admin Dashboard
///
/// ## Prinsip Umum
/// 
/// 1. **Konsistensi** - Gunakan komponen yang sama untuk fungsi yang sama di seluruh aplikasi
/// 2. **Aksesibilitas** - Semua komponen harus memenuhi standar aksesibilitas WCAG 2.1 AA
/// 3. **Responsivitas** - Komponen harus menyesuaikan diri dengan ukuran layar
/// 4. **Efisiensi** - Gunakan komponen yang dapat di-reuse
/// 5. **Maintainability** - Gunakan design tokens untuk konsistensi
/// 
/// ## Struktur Grid
/// 
/// Dashboard admin menggunakan sistem grid responsif dengan breakpoint berikut:
/// - Mobile: < 600px (4 kolom)
/// - Tablet: 600px - 900px (8 kolom)
/// - Desktop Kecil: 900px - 1200px (12 kolom)
/// - Desktop Besar: > 1200px (16 kolom)
/// 
/// Gunakan kelas `ResponsiveGrid` untuk mengakses utilitas grid.
/// 
/// ## Komponen Neumorphic
/// 
/// Untuk elemen visual yang memerlukan kedalaman, gunakan komponen Neumorphic:
/// ```dart
/// AdminTheme.neumorphicContainer(
///   child: YourWidget(),
///   pressed: false, // true untuk efek "ditekan"
/// )
/// ```
/// 
/// ## Warna & Tema
/// 
/// Gunakan tema yang disediakan oleh `AdminTheme` dan design tokens dari `AdminDesignTokens`:
/// ```dart
/// final theme = AdminTheme.getLightTheme();
/// // Gunakan color scheme dari tema
/// final primaryColor = theme.colorScheme.primary;
/// ```
/// 
/// ## Spasi & Jarak
/// 
/// Gunakan spasi konsisten dari `AdminDesignTokens`:
/// ```dart
/// // Spasi vertikal 16px
/// AdminDesignTokens.verticalSpacerMd
/// // Atau langsung: SizedBox(height: AdminDesignTokens.spacingMd)
/// ```
/// 
/// ## Tipografi
/// 
/// Gunakan style teks dari theme:
/// ```dart
/// Text(
///   'Judul',
///   style: Theme.of(context).textTheme.titleLarge,
/// )
/// ```
/// 
/// ## Aksesibilitas
/// 
/// Pastikan semua komponen memenuhi persyaratan aksesibilitas:
/// 
/// 1. **Kontras Warna** - Rasio kontras minimal 4.5:1 untuk teks normal dan 3:1 untuk teks besar
/// 2. **Ukuran Sentuh** - Area sentuh minimal 44x44px
/// 3. **Label Semantik** - Gunakan `Semantics` dan `ExcludeSemantics` untuk screen reader
/// 4. **Fokus Keyboard** - Semua interaksi harus dapat diakses dengan keyboard
/// 
/// Contoh implementasi semantik:
/// ```dart
/// Semantics(
///   label: 'Tombol tambah',
///   hint: 'Ketuk untuk menambahkan item baru',
///   child: YourButton(),
/// )
/// ```
/// 
/// ## Performa
/// 
/// Untuk performa optimal:
/// 
/// 1. Gunakan `const` untuk widget yang tidak berubah
/// 2. Hindari rebuild yang tidak perlu dengan `const` constructor
/// 3. Gunakan `ListView.builder` untuk daftar panjang
/// 4. Implementasikan paginasi untuk data besar
/// 
/// ## Filter & Pencarian
/// 
/// Komponen pencarian dan filter harus menerapkan:
/// 
/// 1. Debouncing untuk input pencarian
/// 2. Indikator loading saat memproses
/// 3. Kondisi kosong saat tidak ada hasil
/// 4. Persistensi state filter saat navigasi
/// 
/// ## Chart & Visualisasi Data
/// 
/// Visualisasi data harus:
/// 
/// 1. Responsif terhadap ukuran layar
/// 2. Menyediakan tooltip untuk detail
/// 3. Menggunakan warna yang konsisten
/// 4. Menampilkan alternative text untuk aksesibilitas
/// 
/// ## Error Handling
/// 
/// Error handling harus:
/// 
/// 1. Memberikan pesan error yang jelas
/// 2. Menyediakan tindakan pemulihan
/// 3. Mempertahankan data yang dimasukkan pengguna
/// 4. Log error untuk debugging
/// 
/// ## State Management
/// 
/// Dashboard menggunakan BLoC pattern untuk state management:
/// 
/// 1. Pisahkan logic bisnis dari UI
/// 2. Gunakan event untuk aksi
/// 3. Gunakan state untuk representasi UI
/// 4. Hindari side-effect dalam BLoC
/// 
/// ## Deliverables
/// 
/// Setiap komponen harus mencakup:
/// 
/// 1. Code documentation dengan dartdoc
/// 2. Contoh penggunaan
/// 3. Kriteria aksesibilitas
/// 4. Unit tests
/// 5. Performance benchmark (opsional)
/// 
/// ## Widget Catalog
/// 
/// Berikut adalah katalog widget yang tersedia:
/// 
/// ### 1. ServiceCardWidget
/// Widget untuk menampilkan informasi layanan.
/// ```dart
/// ServiceCardWidget(
///   service: serviceData,
///   onUpdateStatus: _handleStatusUpdate,
///   onUpdateCost: _handleCostUpdate,
///   currencyFormat: currencyFormat,
/// )
/// ```
/// 
/// ### 2. FilterWidget
/// Widget untuk memfilter data berdasarkan kriteria.
/// ```dart
/// FilterWidget(
///   selectedFilter: _selectedFilter,
///   startDate: _startDate,
///   endDate: _endDate,
///   onFilterChanged: _handleFilterChange,
///   onShowDateRangePicker: _showDatePicker,
///   onClearDateRange: _clearDateRange,
/// )
/// ```
/// 
/// ### 3. SearchBarWidget
/// Widget pencarian dengan debouncing.
/// ```dart
/// SearchBarWidget(
///   controller: _searchController,
///   onChanged: _handleSearch,
///   hintText: 'Cari berdasarkan nama...',
/// )
/// ``` 