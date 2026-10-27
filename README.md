# Hiroshima Mobile

Aplikasi POS & Order Mobile/Tablet (Flutter) untuk Hiroshima Japanese Street Food.

## Endpoint Backend API
Aplikasi ini secara bawaan (default) terhubung ke domain produksi:
```text
https://hiroshima.web.id/api/v1
```

- Endpoint dapat diganti sewaktu-waktu di layar login melalui tombol pengaturan server (*Server Config Sheet*).
- Tersedia opsi preset cepat:
  - **Produksi**: `https://hiroshima.web.id/api/v1`
  - **Localhost**: `http://127.0.0.1:8000/api/v1`
  - **Emulator Android**: `http://10.0.2.2:8000/api/v1`
  - **Laragon**: `http://hiroshima.test/api/v1`
- Anda juga dapat menentukan URL saat build menggunakan flag:
  ```bash
  flutter run --dart-define=API_BASE_URL=https://hiroshima.web.id/api/v1
  ```

## Fitur Utama
- Flutter Framework (Android & iOS / Tablet & Phone)
- Sinkronisasi Data Offline-First (Outbox Queue & Auto-Sync)
- POS Transaksi Cepat & Split Bill
- Otorisasi Supervisor / Kasir via PIN & API Guard
- Pencetakan Struk Bluetooth / Network Thermal Printer (58mm & 80mm)

## Menjalankan Aplikasi
```bash
flutter pub get
flutter run
```
