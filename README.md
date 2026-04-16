# web-server-hardening-auto

Web Server Hardening Auto Version. Script otomatis untuk mengamankan (hardening) web server Apache dan Nginx di lingkungan Ubuntu (Raw Server) maupun aaPanel.

## 🚀 Fitur Lengkap

Skrip ini dirancang untuk bekerja secara non-destruktif (aman dari duplikasi konfigurasi) dan mencakup berbagai aspek keamanan lapisan server hingga aplikasi.

### 🌟 Fitur Utama
* **Dukungan Multi-Environment:** Kompatibel penuh dengan **Raw Server** (Ubuntu/Debian murni) maupun server yang menggunakan *Control Panel* seperti **aaPanel**, tanpa merusak struktur direktori *build* bawaan panel.
* **Pilihan Web Server Fleksibel:** Mendukung hardening spesifik untuk **Apache**, **Nginx**, atau keduanya sekaligus secara bersamaan.

### 🛡️ Keamanan Sistem & Jaringan
* **Otomatisasi Firewall (UFW):** Mengaktifkan dan mengonfigurasi UFW secara aman (hanya membuka port esensial: `80` HTTP, `443` HTTPS, dan SSH).
* **Service Pruning:** Menonaktifkan layanan bawaan OS yang tidak diperlukan (seperti *bluetooth*, *cups*, *avahi-daemon*) untuk mengecilkan celah serangan (*attack surface*).

### 🌐 Proteksi Web Server (Apache & Nginx)
* **Pencegahan Information Disclosure:** Menyembunyikan versi web server, *banner* OS, dan *header* `X-Powered-By` agar tidak mudah diidentifikasi oleh *bot/scanner* peretas.
* **Injeksi HTTP Security Headers:** Secara otomatis memasang *header* keamanan krusial untuk mencegah serangan web modern:
  * `X-Frame-Options: SAMEORIGIN` (Mencegah Clickjacking)
  * `X-Content-Type-Options: nosniff` (Mencegah MIME-sniffing)
  * `X-XSS-Protection: 1; mode=block` (Mencegah Cross-Site Scripting)
  * `Referrer-Policy: strict-origin-when-cross-origin`
* **Proteksi File & Direktori Sensitif:** Memblokir akses publik ke file krusial seperti `.env`, `.git`, `.log`, `.bak`, `.sql`, `.sh`, dll.
* **Disable Directory Listing (Autoindex):** Mematikan fitur bawaan Apache yang menampilkan isi folder web secara publik.

### 🐘 Hardening PHP (Anti-Web Shell)
* **Smart Multi-PHP Scanner:** Script otomatis melacak dan mengamankan **seluruh versi PHP** yang terinstal di server (sangat optimal untuk aaPanel yang sering menjalankan banyak versi PHP).
* **Pemblokiran Fungsi Berbahaya:** Menginjeksi parameter `disable_functions` untuk melumpuhkan eksekusi *command* OS dari PHP yang sering digunakan oleh *backdoor* atau *web shell* (seperti `shell_exec`, `system`, `passthru`, `exec`, `symlink`, `phpinfo`, dll).
* **Auto-Backup Konfigurasi:** Skrip selalu membuat salinan `php.ini.bak` sebelum melakukan modifikasi.

### ✅ Validasi & UX
* **Indikator Real-time:** Memberikan status berhasil (✔) atau gagal (✖) secara langsung saat setiap perintah dieksekusi.
* **Injeksi Non-Destructive:** Skrip akan mengecek terlebih dahulu apakah *rule* keamanan sudah ada di dalam konfigurasi, untuk mencegah duplikasi kode yang bisa membuat *error* web server.
* **Post-Check Validations:** Fitur *Quality Control* di akhir skrip yang membaca ulang file konfigurasi dan status *service* *live* untuk memastikan bahwa aturan benar-benar telah diterapkan dengan sukses.

## 📋 Cakupan Hardening (Coverage)

Berdasarkan 14 standar area web server hardening, skrip ini membagi eksekusi menjadi dua kategori dasar: **Aman Diotomatisasi** dan **Beresiko (Manual)**.

### ✅ Otomatisasi Terpasang (Safe to Automate)
Area berikut diterapkan secara otomatis karena bersifat universal dan meminimalisir risiko website mengalami *downtime* atau *broken layout*:
1. **Update Sistem & Firewall:** UFW diaktifkan otomatis dengan port esensial (80, 443, SSH).
2. **Sembunyikan Versi/Banner:** Mengubah konfigurasi agar OS dan versi server tidak terlihat publik.
3. **Nonaktifkan Modul/Fitur Tidak Perlu:** Menonaktifkan modul `cgi`, `info`, `status`, dan servis `bluetooth`, `cups`, dll.
4. **Security Headers HTTP:** Injeksi `X-Frame-Options`, `X-XSS-Protection`, dll.
5. **Nonaktifkan Directory Listing:** Mematikan fitur `autoindex`.
6. **Proteksi File & Direktori Sensitif:** Memblokir akses `.env`, `.git`, `.log`, dan ekstensi krusial lainnya (HTTP 403 Forbidden).
7. **Anti PHP Shell:** Mencari semua `php.ini` dan mematikan fungsi berbahaya seperti `shell_exec` dan `system`.

---

### ⚠️ Perlu Dikonfigurasi Manual (High Risk for Auto-Script)
Area di bawah ini **sengaja tidak dimasukkan ke dalam skrip otomatis**. Mengubah parameter ini secara otomatis via *bash script* sangat berisiko membuat aplikasi web/API Anda *error*. **Silakan lakukan penyetelan manual sesuai kebutuhan spesifik aplikasi Anda:**
1. **Konfigurasi SSL/TLS Kuat:** Membutuhkan *path* sertifikat spesifik per domain (Let's Encrypt/ZeroSSL).
2. **Batasi Metode HTTP:** Membatasi hanya ke `GET` & `POST` dapat merusak aplikasi modern atau REST API yang membutuhkan `PUT`/`DELETE`.
3. **Timeout & Ukuran Request:** Jika diset terlalu rendah secara global, fitur *upload* *file* di website Anda (seperti gambar/video) akan gagal.
4. **Rate Limiting & Anti-DoS:** Angka *rate limit* harus disesuaikan dengan trafik asli website. Jika diset tebak-tebakan, pengunjung asli bisa terblokir (*False Positive*).
5. **WAF (Web Application Firewall):** Konfigurasi *ModSecurity* / *OWASP CRS* wajib di-*tuning* manual per website agar tidak memblokir *request* normal.
6. **Permission File Konfigurasi:** Mengubah *ownership* (`chown`) secara masal sangat dilarang di *control panel* seperti aaPanel karena akan merusak *user permission* `.user.ini`.

## 📄 Credit & Acknowledgements

Script automasi ini dibangun berdasarkan panduan manual hardening web server yang ditulis oleh **Nur Muhammad Wafa**. 

Referensi sumber asli beserta dokumentasi lengkapnya dapat dilihat pada tautan berikut:
🔗 **[Web Server Hardening CheatSheet | Nur Muhammad Wafa](https://nmwafa.github.io/notes/web-server-hardening)**

---
*Disclaimer: Gunakan script ini dengan bijak dan pastikan Anda sudah melakukan backup konfigurasi server Anda sebelum menjalankannya.*
