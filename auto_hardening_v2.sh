#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31m✖ Harap jalankan script ini sebagai root (gunakan sudo)!\033[0m"
  exit 1
fi

# Warna untuk output
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

# Fungsi untuk mengecek status perintah eksekusi (Real-time)
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  [✔] Berhasil: $1${RESET}"
    else
        echo -e "${RED}  [✖] Gagal: $1${RESET}"
    fi
}

# Fungsi untuk verifikasi konfigurasi akhir (Post-Check)
verify_step() {
    local desc=$1
    local check_cmd=$2
    if eval "$check_cmd" >/dev/null 2>&1; then
        echo -e "  [${GREEN}✔${RESET}] $desc"
    else
        echo -e "  [${RED}✖${RESET}] $desc"
    fi
}

echo -e "${YELLOW}==============================================${RESET}"
echo -e "${YELLOW}   Auto Web Server Hardening Tool v2          ${RESET}"
echo -e "${YELLOW}   Support: Raw Ubuntu Server & aaPanel       ${RESET}"
echo -e "${YELLOW}==============================================${RESET}"

# --- PILIH ENVIRONMENT ---
echo -e "\n${CYAN}Pilih Environment Server Anda:${RESET}"
echo "1) Raw Server (Ubuntu Standar)"
echo "2) aaPanel (Direktori di /www/server/)"
read -p "Masukkan pilihan (1/2): " env_choice

if [ "$env_choice" == "2" ]; then
    ENV_TYPE="aapanel"
    NGINX_CONF="/www/server/nginx/conf/nginx.conf"
    APACHE_CONF="/www/server/apache/conf/httpd.conf"
    PHP_SEARCH_DIR="/www/server/php"
    CMD_NGINX_RELOAD="/etc/init.d/nginx reload"
    CMD_APACHE_RELOAD="/etc/init.d/httpd reload"
    SVC_NGINX="nginx"
    SVC_APACHE="httpd"
else
    ENV_TYPE="raw"
    NGINX_CONF="/etc/nginx/nginx.conf"
    APACHE_CONF_DIR="/etc/apache2"
    APACHE_SEC_CONF="/etc/apache2/conf-available/security.conf"
    PHP_SEARCH_DIR="/etc/php"
    CMD_NGINX_RELOAD="systemctl reload nginx"
    CMD_APACHE_RELOAD="systemctl restart apache2"
    SVC_NGINX="nginx"
    SVC_APACHE="apache2"
fi

# --- PILIH WEB SERVER ---
echo -e "\n${CYAN}Pilih Web Server yang digunakan:${RESET}"
echo "1) Apache"
echo "2) Nginx"
echo "3) Keduanya"
read -p "Masukkan pilihan (1/2/3): " web_choice


# --- BAGIAN 1: PERSIAPAN SISTEM & FIREWALL ---
echo -e "\n${CYAN}[1/4] Memulai Persiapan Sistem...${RESET}"
if [ "$ENV_TYPE" == "raw" ]; then
    apt update > /dev/null 2>&1
    check_status "Update repository sistem"
fi

if command -v ufw >/dev/null 2>&1; then
    ufw --force enable > /dev/null 2>&1
    ufw allow ssh > /dev/null 2>&1
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    check_status "Konfigurasi Firewall (UFW) HTTP, HTTPS, SSH"
else
    echo -e "${YELLOW}  [!] UFW tidak terinstal, melewati konfigurasi firewall bawaan.${RESET}"
fi


# --- BAGIAN 2: APACHE ---
if [ "$web_choice" == "1" ] || [ "$web_choice" == "3" ]; then
    echo -e "\n${CYAN}[2/4] Memulai Hardening Apache...${RESET}"
    
    if [ "$ENV_TYPE" == "raw" ]; then
        apt install apache2 -y > /dev/null 2>&1
        check_status "Instalasi Apache2"
        
        # Sembunyikan Versi (Raw)
        if [ -f "$APACHE_SEC_CONF" ]; then
            sed -i 's/^ServerTokens OS/ServerTokens Prod/' "$APACHE_SEC_CONF"
            sed -i 's/^ServerSignature On/ServerSignature Off/' "$APACHE_SEC_CONF"
            check_status "Sembunyikan Versi/Banner Apache"
        fi

        # Disable autoindex & enable headers (Raw)
        a2dismod -q status info userdir cgi autoindex > /dev/null 2>&1
        a2enmod -q headers rewrite ssl > /dev/null 2>&1
        check_status "Optimasi Modul Apache"

        # Injeksi Headers (Raw)
        sed -i '/<IfModule mod_headers.c>/,/<\/DirectoryMatch>/d' "$APACHE_SEC_CONF" 2>/dev/null
        cat <<EOF >> "$APACHE_SEC_CONF"
<IfModule mod_headers.c>
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header unset X-Powered-By
    Header unset Server
</IfModule>
EOF
        check_status "Injeksi Security Headers Apache"

    elif [ "$ENV_TYPE" == "aapanel" ] && [ -f "$APACHE_CONF" ]; then
        # Sembunyikan Versi & Header (aaPanel)
        if grep -q "ServerTokens" "$APACHE_CONF"; then
            sed -i 's/^ServerTokens.*/ServerTokens Prod/' "$APACHE_CONF"
            sed -i 's/^ServerSignature.*/ServerSignature Off/' "$APACHE_CONF"
        else
            echo -e "\nServerTokens Prod\nServerSignature Off" >> "$APACHE_CONF"
        fi
        
        if ! grep -q "X-Frame-Options" "$APACHE_CONF"; then
            echo -e "\n<IfModule mod_headers.c>\n    Header always set X-Frame-Options \"SAMEORIGIN\"\n    Header always set X-Content-Type-Options \"nosniff\"\n    Header always set X-XSS-Protection \"1; mode=block\"\n    Header unset X-Powered-By\n</IfModule>" >> "$APACHE_CONF"
        fi
        check_status "Sembunyikan Versi & Injeksi Headers Apache (aaPanel)"
    fi

    eval "$CMD_APACHE_RELOAD" > /dev/null 2>&1
    check_status "Reload layanan Apache"
fi

# --- BAGIAN 3: NGINX ---
if [ "$web_choice" == "2" ] || [ "$web_choice" == "3" ]; then
    echo -e "\n${CYAN}[3/4] Memulai Hardening Nginx...${RESET}"
    
    if [ "$ENV_TYPE" == "raw" ]; then
        apt install nginx -y > /dev/null 2>&1
        check_status "Instalasi Nginx"
    fi

    if [ -f "$NGINX_CONF" ]; then
        # Sembunyikan versi Nginx
        sed -i 's/# server_tokens off;/server_tokens off;/' "$NGINX_CONF"
        if ! grep -q "server_tokens off;" "$NGINX_CONF"; then
             sed -i '/http {/a \    server_tokens off;' "$NGINX_CONF"
        fi
        check_status "Sembunyikan Versi Nginx (server_tokens off)"

        # Security Headers Nginx
        if ! grep -q "X-Frame-Options" "$NGINX_CONF"; then
            sed -i '/http {/a \    add_header X-Frame-Options "SAMEORIGIN" always;\n    add_header X-Content-Type-Options "nosniff" always;\n    add_header X-XSS-Protection "1; mode=block" always;\n    add_header Referrer-Policy "strict-origin-when-cross-origin" always;' "$NGINX_CONF"
            check_status "Injeksi Security Headers Nginx"
        fi
    else
        echo -e "${RED}  [✖] File konfigurasi Nginx tidak ditemukan di $NGINX_CONF${RESET}"
    fi

    # Raw server specific protections
    if [ "$ENV_TYPE" == "raw" ] && [ -f /etc/nginx/sites-available/default ]; then
        if ! grep -q "\.env" /etc/nginx/sites-available/default; then
            sed -i '/server_name _;/a \    location ~ /\\. { deny all; access_log off; log_not_found off; }\n    location ~* \\.(env|log|bak|sql|config|conf|ini|sh|git)$ { deny all; }' /etc/nginx/sites-available/default
            check_status "Proteksi File Sensitif Nginx (.env, .git, dll)"
        fi
    fi

    # Test dan Reload
    nginx -t > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        eval "$CMD_NGINX_RELOAD" > /dev/null 2>&1
        check_status "Reload layanan Nginx"
    else
        echo -e "${RED}  [✖] Syntax error pada konfigurasi Nginx! Lewati reload.${RESET}"
    fi
fi

# --- BAGIAN 4: PHP HARDENING (Berlaku untuk Multi-PHP) ---
echo -e "\n${CYAN}[4/4] Hardening PHP...${RESET}"
PHP_INIS=$(find "$PHP_SEARCH_DIR" -name "php.ini" 2>/dev/null)

if [ -n "$PHP_INIS" ]; then
    for ini in $PHP_INIS; do
        cp "$ini" "${ini}.bak"
        # Menerapkan disable_functions
        sed -i 's/^disable_functions =.*/disable_functions = curl_multi_exec, popen, passthru, exec, symlink, proc_open, shell_exec, show_source, allow_url_fopen, system, parse_ini_file, php_uname, posix_getpwuid, putenv, mail, link, phpinfo/' "$ini"
        check_status "Injeksi disable_functions pada $ini"
    done
    
    # Reload layanan PHP-FPM jika ada
    if [ "$ENV_TYPE" == "raw" ]; then
        systemctl restart $(systemctl list-units --type=service | grep -o 'php.*-fpm.service') >/dev/null 2>&1
    else
        # Reload semua versi PHP di aaPanel
        for version in 56 70 71 72 73 74 80 81 82 83; do
            if [ -f "/etc/init.d/php-fpm-$version" ]; then
                /etc/init.d/php-fpm-$version reload >/dev/null 2>&1
            fi
        done
    fi
    check_status "Reload layanan PHP-FPM"
else
    echo -e "${YELLOW}  [!] File php.ini tidak ditemukan. Melewati langkah PHP.${RESET}"
fi


# =========================================================================
# ================= LAPORAN VERIFIKASI AKHIR (POST-CHECK) =================
# =========================================================================
echo -e "\n${YELLOW}==============================================${RESET}"
echo -e "${YELLOW}   LAPORAN VERIFIKASI AKHIR KONFIGURASI       ${RESET}"
echo -e "${YELLOW}==============================================${RESET}"

if command -v ufw >/dev/null 2>&1; then
    echo -e "\n${CYAN}1. Pemeriksaan Firewall (UFW):${RESET}"
    verify_step "Firewall (UFW) berstatus Aktif" "ufw status | grep -qw 'active'"
    verify_step "Port 80 (HTTP) diizinkan di UFW" "ufw status | grep -qw '80/tcp'"
    verify_step "Port 443 (HTTPS) diizinkan di UFW" "ufw status | grep -qw '443/tcp'"
fi

if [ "$web_choice" == "1" ] || [ "$web_choice" == "3" ]; then
    echo -e "\n${CYAN}2. Pemeriksaan Apache:${RESET}"
    verify_step "Layanan Apache berjalan" "systemctl is-active --quiet $SVC_APACHE || /etc/init.d/$SVC_APACHE status | grep -q 'running'"
    
    if [ "$ENV_TYPE" == "raw" ]; then
        verify_step "Versi Apache disembunyikan" "grep -Eq '^\s*ServerTokens Prod' $APACHE_SEC_CONF"
        verify_step "Security Headers tertulis" "grep -q 'X-Frame-Options' $APACHE_SEC_CONF"
    else
        verify_step "Versi Apache disembunyikan" "grep -Eq '^\s*ServerTokens Prod' $APACHE_CONF"
        verify_step "Security Headers tertulis" "grep -q 'X-Frame-Options' $APACHE_CONF"
    fi
fi

if [ "$web_choice" == "2" ] || [ "$web_choice" == "3" ]; then
    echo -e "\n${CYAN}3. Pemeriksaan Nginx:${RESET}"
    verify_step "Layanan Nginx berjalan" "systemctl is-active --quiet $SVC_NGINX || /etc/init.d/$SVC_NGINX status | grep -q 'running'"
    verify_step "Versi Nginx disembunyikan" "grep -Eq '^\s*server_tokens off;' $NGINX_CONF"
    verify_step "Security Headers tertulis" "grep -q 'X-Content-Type-Options' $NGINX_CONF"
fi

if [ -n "$PHP_INIS" ]; then
    echo -e "\n${CYAN}4. Pemeriksaan PHP:${RESET}"
    # Mengecek file php.ini pertama yang ditemukan saja sebagai sampel
    FIRST_PHP_INI=$(echo "$PHP_INIS" | head -n 1)
    verify_step "Fungsi rentan dinonaktifkan (shell_exec, dll) pada $FIRST_PHP_INI" "grep -q 'disable_functions.*shell_exec' $FIRST_PHP_INI"
fi

echo -e "\n${GREEN}==============================================${RESET}"
echo -e "${GREEN}   Proses Selesai! (Mode: $ENV_TYPE)          ${RESET}"
echo -e "${GREEN}==============================================${RESET}"