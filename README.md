<div align="center">

```
  ███╗   ██╗ ██████╗ ██████╗ ██████╗  ██████╗ ██████╗ ████████╗
  ████╗  ██║██╔═══██╗██╔══██╗██╔══██╗██╔════╝ ██╔══██╗╚══██╔══╝
  ██╔██╗ ██║██║   ██║██████╔╝██║  ██║██║  ███╗██████╔╝   ██║
  ██║╚██╗██║██║   ██║██╔══██╗██║  ██║██║   ██║██╔═══╝    ██║
  ██║ ╚████║╚██████╔╝██║  ██║██████╔╝╚██████╔╝██║        ██║
  ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝        ╚═╝
```

**Yerel AI Chat Arayüzü — Local AI Chat Interface**

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Ollama](https://img.shields.io/badge/Ollama-Compatible-black?style=flat-square)](https://ollama.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![OWASP](https://img.shields.io/badge/OWASP_Top_10-Mitigated-blue?style=flat-square)](https://owasp.org/Top10/)
[![SSO](https://img.shields.io/badge/Microsoft_SSO-Entra_ID-0078D4?style=flat-square&logo=microsoft&logoColor=white)](https://learn.microsoft.com/entra)
[![Cloudflare](https://img.shields.io/badge/Cloudflare_Tunnel-Ready-F38020?style=flat-square&logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

*İnternet gerekmez. Verileriniz dışarı çıkmaz. Tamamen yerel.*

</div>

---

## 📋 İçindekiler

- [Ne Yapar?](#-ne-yapar)
- [Ekran Görüntüleri](#-ekran-görüntüleri)
- [Hızlı Başlangıç](#-hızlı-başlangıç)
- [Gereksinimler](#-gereksinimler)
- [Kurulum — macOS](#-kurulum--macos)
- [Kurulum — Ubuntu / Debian](#-kurulum--ubuntu--debian)
- [Kurulum — Docker](#-kurulum--docker)
- [Kurulum Sihirbazı](#-kurulum-sihirbazı)
- [Production Kurulumu](#-production-kurulumu)
- [Microsoft SSO](#-microsoft-sso-entra-id--azure-ad)
- [Dosya Yükleme](#-dosya-yükleme)
- [Komutlar](#-komutlar)
- [Özellikler](#-özellikler)
- [Model Kategorileri](#-model-kategorileri)
- [Dil Desteği](#-dil-desteği)
- [Güvenlik (OWASP Top 10)](#-güvenlik-owasp-top-10)
- [Proje Yapısı](#-proje-yapısı)
- [Yapılandırma (.nordgpt.conf)](#-yapılandırma-nordgptconf)
- [API Referansı](#-api-referansı)
- [Sık Sorulan Sorular](#-sık-sorulan-sorular)
- [Katkı](#-katkı)

---

## 🤖 Ne Yapar?

NordGpT, **tamamen yerel çalışan** bir AI chat arayüzüdür. ChatGPT veya Claude gibi bir deneyim sunar, ancak verileriniz hiçbir zaman sunucunuzu terk etmez.

- **Tek komutla başlar:** `./nordgpt.sh`
- Ollama'yı otomatik kurar ve yapılandırır
- Donanımınızı analiz ederek uygun modeli önerir
- Sektörünüze özel (siber güvenlik, finans, yazılım...) model seçimi
- ChatGPT benzeri modern web arayüzü — tarayıcınızda açılır
- **Microsoft Entra ID / Azure AD** ile kurumsal SSO desteği
- **Dosya yükleme** — görsel, PDF, DOCX ve TXT desteği
- **Cloudflare Tunnel** ile güvenli production dağıtımı

---

## 📸 Ekran Görüntüleri

| Chat Arayüzü | Ayarlar & Model Kütüphanesi | Login |
|---|---|---|
| Dark tema, streaming yanıt, dosya ekleme | Kategori bazlı model indirme | Güvenli giriş + MS SSO |

---

## ⚡ Hızlı Başlangıç

```bash
# Repoyu klonla
git clone https://github.com/davudows/NordGpT.git
cd NordGpT

# Çalıştırılabilir yap ve başlat
chmod +x nordgpt.sh
./nordgpt.sh
```

İlk çalıştırmada kurulum sihirbazı açılır. Her şeyi otomatik olarak ayarlar.
Tarayıcınızda `http://localhost:7860` adresinde açılır.

---

## 🖥️ Gereksinimler

| Bileşen | Minimum | Önerilen |
|---|---|---|
| **OS** | macOS 12+ / Ubuntu 20.04+ | macOS 14+ / Ubuntu 22.04+ |
| **RAM** | 8 GB | 16 GB+ |
| **Disk** | 5 GB serbest | 20 GB+ (modeller için) |
| **Python** | 3.10+ | 3.11+ |
| **GPU** | Opsiyonel | NVIDIA 8GB+ VRAM (hız için) |

> **GPU yoksa endişelenme** — NordGpT donanımına göre en uygun modeli otomatik seçer.

---

## 🍎 Kurulum — macOS

### Yöntem 1: Otomatik (Önerilen)

```bash
git clone https://github.com/davudows/NordGpT.git
cd NordGpT
chmod +x nordgpt.sh
./nordgpt.sh
```

Script otomatik olarak şunları yapar:
- Homebrew ile Python 3 kurulumu (yoksa)
- Ollama kurulumu
- Python sanal ortamı oluşturma
- Bağımlılıkları yükleme
- Kurulum sihirbazını başlatma

### Yöntem 2: Manuel

```bash
# Homebrew yoksa kur
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ollama kur
brew install ollama

# Ollama'yı başlat
ollama serve &

# İstediğin modeli indir
ollama pull llama3.1:8b

# Python bağımlılıklarını kur
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Başlat
python app.py
```

---

## 🐧 Kurulum — Ubuntu / Debian

### Yöntem 1: Otomatik (Önerilen)

```bash
git clone https://github.com/davudows/NordGpT.git
cd NordGpT
chmod +x nordgpt.sh
./nordgpt.sh
```

### Yöntem 2: Manuel

```bash
# Sistem bağımlılıkları
sudo apt update && sudo apt install -y python3 python3-pip python3-venv curl

# Ollama kur
curl -fsSL https://ollama.com/install.sh | sh

# Systemd servisi olarak başlat (opsiyonel)
sudo systemctl enable --now ollama

# Model indir
ollama pull llama3.1:8b

# Python ortamı
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Başlat
python3 app.py
```

### Arch Linux

```bash
sudo pacman -S python python-pip curl
curl -fsSL https://ollama.com/install.sh | sh
./nordgpt.sh
```

### Fedora / RHEL

```bash
sudo dnf install python3 python3-pip curl
curl -fsSL https://ollama.com/install.sh | sh
./nordgpt.sh
```

---

## 🐳 Kurulum — Docker

```dockerfile
# Dockerfile (yakında)
```

> Docker desteği gelecek sürümde eklenecek. Şimdilik yukarıdaki yöntemleri kullanın.

---

## 🧙 Kurulum Sihirbazı

`./nordgpt.sh` ilk çalıştırıldığında kurulum sihirbazı açılır:

### Adım 1 — Mevcut Kurulum Kontrolü
```
── Mevcut Kurulum Durumu ────────────────────
✔  Ollama kurulu (0.3.12)
✔  Ollama servisi çalışıyor
✔  2 yüklü model:
     • llama3.1:8b
     • mistral:7b
✗  NordGpT yapılandırması yok
────────────────────────────────────────────
```

### Adım 2 — Donanım Analizi

NordGpT RAM'i ve GPU VRAM'ini algılar; 5 katmana göre uygun modelleri önerir:

| Katman | RAM | Önerilen Modeller |
|--------|-----|-------------------|
| 🌱 Çok Düşük | < 4 GB | qwen2.5:0.5b, tinyllama, gemma3:1b |
| 🌿 Düşük | 4–8 GB | qwen2.5:1.5b, phi3:mini, gemma3:1b |
| ⚡ Orta | 8–16 GB | phi4-mini, qwen2.5:7b, gemma3:4b |
| 🔥 Yüksek | 16–48 GB | qwen2.5:14b, phi4, deepseek-r1:7b |
| 🚀 Çok Yüksek | 48+ GB | qwen2.5:32b, llama3.1:70b, deepseek-r1:14b |

```
── Donanım ──────────────────────────────────
RAM:     64 GB
CPU:     4 çekirdek
GPU:     Yok
Seviye:  🚀 Çok Yüksek — 32B+ modeller çalışır
────────────────────────────────────────────
```

### Adım 3 — Dil Seçimi
```
Arayüz dilini seçin:
[1] 🇹🇷 Türkçe  ← varsayılan
[2] 🇬🇧 English
[3] 🇩🇪 Deutsch
[4] 🇫🇷 Français
[5] 🇪🇸 Español
[6] 🇸🇦 العربية
[7] 🇨🇳 中文
```

### Adım 4 — Sektör Seçimi
```
Hangi alanda kullanacaksınız?
[1] 🔐 Siber Güvenlik   — Pentest, CTF, zafiyet analizi
[2] 📈 Finans & Ekonomi  — Piyasa analizi, trading
[3] 💻 Yazılım Geliştirme — Kod, debug, mimari
[4] 🤖 Genel Kullanım   — Her türlü soru
[5] ✍️  Yaratıcı Yazarlık — Hikaye, şiir, içerik
[6] 📊 Veri Bilimi & AI  — ML, analiz, istatistik
```

### Adım 5 — Model Seçimi (Donanım + Dil Uyumlu)

Birden fazla model seçerek indirebilirsiniz. İlk seçilen varsayılan olur.

```
Önerilen modeller (donanım: very_high | ~RAM gereksinimi):

[ 1] qwen2.5:32b             ~ 20.0 GB  Çok güçlü
[ 2] deepseek-r1:14b         ~  9.0 GB  Derin reasoning
[ 3] llama3.1:70b            ~ 42.0 GB  En güçlü (64GB+)
[ 4] qwen2.5:14b             ~  9.0 GB  Hız/kalite dengesi
[ A] Hepsini indir           (toplam ~80 GB disk)
[ 0] Manuel gir

  Tek seçim → 2   |  Çoklu → 1 3   |  Hepsi → A
```

> Türkçe veya Arapça seçildiğinde dil uyumsuz modeller otomatik olarak düşük önceliğe alınır.

### Adım 6 — Giriş Yöntemi Seçimi

```
── Giriş Yöntemi ─────────────────────────────
[1] 🔑 Kullanıcı adı + şifre  ← yerel ağ, VPN, iç kullanım
[2] 🏢 Yalnızca Microsoft SSO  ← kurumsal, dışa açık erişim gerekir
[3] 🔀 Her ikisi               ← hem şifre hem MS SSO aktif
```

> **[2] seçilirse uyarı:** Microsoft SSO, callback için HTTPS ile erişilebilir bir public URL gerektirir. Yerel IP ile çalışmaz. Cloudflare Tunnel, Nginx+SSL veya kurumsal VPN+DNS gereklidir.
> Bkz. → [Microsoft SSO + Cloudflare Tunnel](#microsoft-sso--cloudflare-tunnel-kurulumu)

### Adım 7 — Admin Hesabı Oluşturma

> Giriş yöntemi [1] veya [3] seçildiyse oluşturulur. [2] (Yalnızca MS SSO) seçildiyse bu adım atlanır.

```
── Admin Hesabı Oluştur ──────────────────────
  Sisteme sadece admin yeni kullanıcı ekleyebilir.

? Admin kullanıcı adı [admin]: davut
? Admin şifresi (min 8 karakter): ••••••••
? Şifre tekrar: ••••••••
✔  Admin hesabı oluşturuldu: davut
```

### Adım 8 — Microsoft SSO (Opsiyonel)

> Giriş yöntemi [2] veya [3] seçildiyse bu adım açılır.

```
── Microsoft Entra ID / Azure AD SSO ────────
? Application (Client) ID:  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
? Client Secret (Value):    ••••••••••••••••
? Tenant ID [common]:
? Redirect URI:  https://chat.sirket.com/auth/microsoft/callback
? İzin verilen domain'ler [boş = tümü]:  sirket.com
✔  Microsoft SSO yapılandırıldı.
```

### Adım 9 — CAPTCHA (Opsiyonel)
```
── Cloudflare Turnstile CAPTCHA ─────────────
  Login formuna CAPTCHA eklemek ister misiniz?
  (Basılı-tut CAPTCHA her zaman aktiftir — harici servis gerekmez)
  Cloudflare Turnstile için API anahtarları girin veya atlayın.

? Turnstile Site Key [boş bırak = atla]:
? Turnstile Secret Key:
✔  Turnstile CAPTCHA yapılandırıldı.
```

---

## 🚀 Production Kurulumu

### Cloudflare Tunnel (Önerilen)

Cloudflare Tunnel, açık port veya NAT yapılandırması gerektirmeden uygulamanızı güvenli şekilde internete açar.

```bash
# cloudflared kur (Ubuntu/Debian)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# Cloudflare hesabınıza giriş yapın
cloudflared tunnel login

# Tunnel oluşturun
cloudflared tunnel create nordgpt

# Yapılandırma dosyası (~/.cloudflared/config.yml)
cat > ~/.cloudflared/config.yml <<EOF
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: chat.nordisglobal.com
    service: http://localhost:7860
  - service: http_status:404
EOF

# DNS kaydı oluşturun
cloudflared tunnel route dns nordgpt chat.nordisglobal.com

# Tunnel'ı başlatın
cloudflared tunnel run nordgpt
```

> Cloudflare Tunnel sayesinde sunucunuzda hiçbir port açmanıza gerek kalmaz. Tüm trafik Cloudflare altyapısı üzerinden şifreli geçer.

---

## 🏢 Microsoft SSO + Cloudflare Tunnel Kurulumu

Microsoft SSO, OAuth2 callback için **HTTPS ile erişilebilir bir public URL** zorunlu kılar. Yerel IP adresleri (192.168.x.x, 10.x.x.x, 172.16.x.x) desteklenmez.

> Kurulum sihirbazında **[2] Yalnızca Microsoft SSO** seçtiyseniz bu adımları tamamlayın.

### Adım 1 — Cloudflare Tunnel ile Public URL Al

```bash
# 1. cloudflared kur (Ubuntu/Debian)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# 2. Cloudflare hesabınıza giriş yapın
cloudflared tunnel login

# 3. Tunnel oluşturun
cloudflared tunnel create nordgpt

# 4. Yapılandırma dosyası
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml <<EOF
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: chat.sirket.com
    service: http://localhost:7860
  - service: http_status:404
EOF

# 5. DNS kaydı oluşturun (Cloudflare DNS'te CNAME otomatik eklenir)
cloudflared tunnel route dns nordgpt chat.sirket.com

# 6. Systemd servisi olarak kur
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

### Adım 2 — Azure Portal Ayarları

1. [portal.azure.com](https://portal.azure.com) → **Microsoft Entra ID** → **App registrations**
2. Uygulamanızı seçin → **Authentication** → **Add a platform** → **Web**
3. **Redirect URI** olarak ekleyin:
   ```
   https://chat.sirket.com/auth/microsoft/callback
   ```
4. **Save**

> Redirect URI, `http://` veya yerel IP ile çalışmaz. Mutlaka `https://` ile başlamalıdır.

### Adım 3 — NordGpT Yapılandırması

`.nordgpt.conf` dosyasını güncelleyin:

```ini
MICROSOFT_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MICROSOFT_CLIENT_SECRET=your_client_secret_value
MICROSOFT_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MICROSOFT_REDIRECT_URI=https://chat.sirket.com/auth/microsoft/callback
ALLOWED_DOMAINS=sirket.com          # boş bırakılırsa tüm MS hesapları
MICROSOFT_ONLY=true
```

```bash
sudo systemctl restart nordgpt
```

### Alternatif: Nginx + Let's Encrypt

Cloudflare Tunnel yerine kendi SSL sertifikanız varsa:

```bash
# Let's Encrypt sertifikası al
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d chat.sirket.com

# Nginx yapılandırması /etc/nginx/sites-available/nordgpt
```
```nginx
server {
    listen 443 ssl;
    server_name chat.sirket.com;
    ssl_certificate     /etc/letsencrypt/live/chat.sirket.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chat.sirket.com/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:7860;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Sistemd Servisi (Linux)

NordGpT'yi sistem başlangıcında otomatik başlatmak için:

```bash
# Servis dosyasını kopyala
sudo cp scripts/nordgpt.service /etc/systemd/system/

# Servis dosyasında kullanıcı ve yol bilgilerini düzenle
sudo nano /etc/systemd/system/nordgpt.service

# Servisi etkinleştir ve başlat
sudo systemctl daemon-reload
sudo systemctl enable --now nordgpt

# Durumu kontrol et
sudo systemctl status nordgpt
```

### Nginx Reverse Proxy (Alternatif)

```nginx
server {
    listen 443 ssl;
    server_name chat.nordisglobal.com;

    ssl_certificate     /etc/letsencrypt/live/chat.nordisglobal.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chat.nordisglobal.com/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:7860;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## 🏢 Microsoft SSO (Entra ID / Azure AD)

NordGpT, Microsoft Entra ID (eski adıyla Azure Active Directory) ile OAuth2 tabanlı kurumsal SSO destekler.

### Azure Portal Yapılandırması

1. [Azure Portal](https://portal.azure.com) → **App registrations** → **New registration**
2. Uygulama adı girin (örn. `NordGpT`)
3. **Redirect URI** olarak şunu ekleyin: `https://chat.nordisglobal.com/auth/microsoft/callback`
4. **Certificates & secrets** → **New client secret** ile secret oluşturun
5. **Overview** sayfasından `Application (client) ID` ve `Directory (tenant) ID` değerlerini kopyalayın

### .nordgpt.conf Yapılandırması

```ini
MICROSOFT_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MICROSOFT_CLIENT_SECRET=your-client-secret
MICROSOFT_TENANT_ID=common          # veya belirli tenant ID
MICROSOFT_REDIRECT_URI=https://chat.nordisglobal.com/auth/microsoft/callback
ALLOWED_DOMAINS=sirket.com,baska.com  # boş bırakılırsa tüm MS hesapları kabul edilir
MICROSOFT_ONLY=true                  # şifre girişini devre dışı bırakır
```

### Çalışma Akışı

```
Kullanıcı → /auth/microsoft
         → Microsoft OAuth2 onay sayfası
         → /auth/microsoft/callback
         → Domain kontrolü (ALLOWED_DOMAINS)
         → Oturum oluşturma → Ana sayfa
```

### MICROSOFT_ONLY Modu

`MICROSOFT_ONLY=true` ayarlandığında:
- Login sayfasındaki şifre formu gizlenir
- Kullanıcı otomatik olarak Microsoft giriş sayfasına yönlendirilir
- Admin hariç tüm kullanıcılar Microsoft hesabıyla giriş yapmak zorundadır

### Domain Allowlist

`ALLOWED_DOMAINS` ile yalnızca belirli kurumsal domain'lerden giriş kabul edilir:

```ini
# Sadece şirket çalışanlarına izin ver
ALLOWED_DOMAINS=sirket.com

# Birden fazla domain
ALLOWED_DOMAINS=sirket.com,partner.com,holding.com.tr

# Boş = tüm Microsoft hesapları (@gmail, @hotmail dahil)
ALLOWED_DOMAINS=
```

---

## 📎 Dosya Yükleme

NordGpT, chat mesajlarına dosya eklemeyi destekler. Paperclip (📎) düğmesine tıklayarak veya sürükle-bırak ile dosya yükleyebilirsiniz.

### Desteklenen Dosya Türleri

| Tür | Format | Model Davranışı |
|---|---|---|
| **Görsel** | JPG, PNG, GIF, WEBP | Base64 olarak multimodal Ollama modeline gönderilir |
| **PDF** | .pdf | Metin çıkarılır, konuşmaya bağlam olarak eklenir |
| **Word** | .docx | Metin çıkarılır, konuşmaya bağlam olarak eklenir |
| **Metin** | .txt | Doğrudan konuşmaya bağlam olarak eklenir |

### Sınırlamalar

| Parametre | Değer |
|---|---|
| Maksimum dosya boyutu | 20 MB |
| Mesaj başına maksimum dosya | 5 adet |
| Görsel desteği | Yalnızca multimodal modeller (`llava`, `bakllava` vb.) |

### Kullanım

```
Chat kutusunun sol alt köşesindeki 📎 düğmesine tıklayın
→ Dosya seçin (veya sürükleyip bırakın)
→ Önizleme gösterilir
→ Mesajınızı yazın ve gönderin
```

> **Not:** PDF ve DOCX dosyalarının metni otomatik olarak çıkarılır ve AI modeline bağlam olarak aktarılır. Görseller için modelin multimodal desteklemesi gerekir (örn. `llava:7b`).

### Yüklenen Dosyalar

Yüklenen dosyalar `data/uploads/` klasöründe saklanır. Sunucunuzdan dışarı çıkmaz.

---

## 📟 Komutlar

```bash
# Normal başlatma
./nordgpt.sh

# Yeni model indir
./nordgpt.sh pull llama3.1:70b
./nordgpt.sh pull qwen2.5:7b
./nordgpt.sh pull deepseek-coder-v2:16b

# Yüklü modelleri listele
./nordgpt.sh list

# Yapılandırmayı sıfırla, ardından sihirbazı tekrar çalıştır
./nordgpt.sh reset   # config dosyasını siler
./nordgpt.sh         # sihirbazı başlatır

# Sohbet geçmişini temizle
./nordgpt.sh clean

# Yardım
./nordgpt.sh help

# Farklı port kullan
NORDGPT_PORT=8080 ./nordgpt.sh
```

---

## ✨ Özellikler

### Chat Arayüzü
| Özellik | Detay |
|---|---|
| **Streaming** | Gerçek zamanlı token akışı, yazma efekti |
| **Markdown** | Başlık, liste, tablo, kod bloğu render |
| **Syntax Highlight** | 100+ dil, highlight.js |
| **Kod Kopyala** | Her kod bloğunda tek tık kopyala |
| **Durdur** | Üretimi anında durdurma (Ctrl+C benzeri) |
| **Geçici Sohbet** | Toggle ile — hiçbir şey kaydedilmez |
| **Mobil** | Responsive tasarım, dokunmatik uyumlu |
| **Dosya Ekleme** | Görsel, PDF, DOCX, TXT — paperclip düğmesiyle |

### Sohbet Yönetimi
| Özellik | Detay |
|---|---|
| **Geçmiş** | Bugün / Dün / Son 7 Gün / Daha Eski grupları |
| **Arama** | Başlığa göre anlık filtreleme |
| **Yeniden Adlandır** | Sohbet başlığını düzenle |
| **Sil** | Tek tek veya toplu silme |
| **Otomatik Başlık** | İlk mesajdan başlık oluşturulur |

### Giriş & Kimlik Doğrulama
| Özellik | Detay |
|---|---|
| **Şifre Girişi** | bcrypt hash, rate limiting, press-and-hold CAPTCHA |
| **Microsoft SSO** | OAuth2 / Entra ID / Azure AD, domain allowlist |
| **MICROSOFT_ONLY** | Şifre girişini devre dışı bırakır, otomatik MS yönlendirmesi |
| **Cloudflare Turnstile** | Opsiyonel harici CAPTCHA (site key + secret key) |
| **Press & Hold CAPTCHA** | 3 saniye basılı tut — harici servis gerektirmez, her zaman aktif |

### ⚙️ Ayarlar Paneli
| Sekme | İçerik |
|---|---|
| **🌐 Dil** | Arayüz dilini değiştir (anlık, yeniden yükleme gerekmez) |
| **📦 Modeller** | Kategoriye göre model indir, ilerleme çubuğu, yüklü model işareti |
| **👥 Kullanıcılar** | Admin paneli — yeni kullanıcı ekle/sil |
| **ℹ️ Hakkında** | Versiyon ve güvenlik bilgisi |

---

## 🗂️ Model Kategorileri

### 🔐 Siber Güvenlik
Pentest, CTF, zafiyet analizi, reverse engineering için optimize.

| Donanım Seviyesi | Önerilen Model | Boyut |
|---|---|---|
| 🔥 Yüksek (32GB+) | `llama3.1:70b`, `mixtral:8x7b` | 40-26 GB |
| ⚡ Orta (16GB+) | `llama3.1:8b`, `qwen2.5:7b` | ~5 GB |
| 🌱 Düşük (<16GB) | `phi3:mini`, `qwen2.5:0.5b` | ~2 GB |

### 📈 Finans & Ekonomi
Piyasa analizi, trading stratejileri, ekonomi.

| Donanım Seviyesi | Önerilen Model | Boyut |
|---|---|---|
| 🔥 Yüksek | `llama3.1:70b`, `qwen2.5:72b` | 40-41 GB |
| ⚡ Orta | `qwen2.5:7b`, `mistral:7b` | ~5 GB |
| 🌱 Düşük | `phi3:mini`, `qwen2.5:0.5b` | ~2 GB |

### 💻 Yazılım Geliştirme
Kod yazma, debug, code review, mimari.

| Donanım Seviyesi | Önerilen Model | Boyut |
|---|---|---|
| 🔥 Yüksek | `deepseek-coder-v2:16b`, `codellama:34b` | 9-19 GB |
| ⚡ Orta | `codellama:13b`, `deepseek-coder:6.7b` | 7-4 GB |
| 🌱 Düşük | `deepseek-coder:1.3b`, `phi3:mini` | <2 GB |

### 🤖 Genel / ✍️ Yaratıcı / 📊 Veri Bilimi
Benzer öneri sistemi — donanım + dil uyumuna göre otomatik sıralama.

---

## 🌍 Dil Desteği

### Arayüz Dilleri
Kurulum sihirbazı ve web arayüzü şu dilleri destekler:

| Dil | Kod | Sihirbaz | Web UI | AI Yanıt Kalitesi |
|---|---|---|---|---|
| 🇹🇷 Türkçe | `tr` | ✅ | ✅ | `qwen2.5`, `llama3.1` ile iyi |
| 🇬🇧 English | `en` | ✅ | ✅ | Tüm modeller |
| 🇩🇪 Deutsch | `de` | ✅ | ✅ | `llama3.1`, `mixtral` ile iyi |
| 🇫🇷 Français | `fr` | ✅ | ✅ | `llama3.1`, `mixtral` ile iyi |
| 🇪🇸 Español | `es` | ✅ | ✅ | `llama3.1`, `mixtral` ile iyi |
| 🇸🇦 العربية | `ar` | ✅ | — | `qwen2.5`, `llama3.1` ile iyi |
| 🇨🇳 中文 | `zh` | ✅ | — | `qwen2.5` ile mükemmel |

> **Dil değişimi:** Web arayüzünde ⚙️ Ayarlar → 🌐 Dil sekmesinden anlık değiştirebilirsiniz.

### Model Seçiminde Dil Uyarısı
Türkçe veya Arapça seçildiğinde, dil desteği zayıf modeller (phi3, tinyllama, gemma) otomatik olarak uyarı ile gösterilir:

```
⚠  phi3:mini modeli tr dili için sınırlı destek sunuyor.
   Daha iyi Türkçe için qwen2.5:7b veya llama3.1:8b öneririz.
   Yine de devam et? [E/h]:
```

---

## 🔐 Güvenlik (OWASP Top 10)

NordGpT, OWASP Top 10 2021 standartlarına göre tasarlanmıştır:

| # | Tehdit | Uygulanan Önlem |
|---|---|---|
| **A01** | Broken Access Control | Auth middleware tüm `/api/*` rotaları korur. Chat sahipliği kontrolü. Admin-only endpoint'ler. |
| **A02** | Cryptographic Failures | **bcrypt** (cost=12) şifre hash'leme. `secrets.token_urlsafe(32)` — 256-bit session token. httponly + samesite=strict cookie. |
| **A03** | Injection | Model adı regex allowlist `^[a-zA-Z0-9][\w\-.:]{0,99}$`. Chat ID UUID validasyonu. Path traversal önleme. Pydantic ile tüm input validasyonu. |
| **A04** | Insecure Design | Yeni kullanıcı **sadece admin** oluşturabilir. Kullanıcılar yalnızca kendi sohbetlerini görebilir. |
| **A05** | Security Misconfiguration | 6 güvenlik header'ı (CSP, X-Frame-Options, HSTS vb.). Localhost-only CORS. Swagger/ReDoc devre dışı (prod). |
| **A07** | Auth Failures | **Rate limiting:** IP başına 5 deneme / 5 dakika (Cloudflare arkasında CF-Connecting-IP kullanılır). 24 saatlik session süresi. Press-and-hold CAPTCHA. Generic hata mesajları (kullanıcı adı enumeration yok). |
| **A09** | Logging Failures | Auth olayları ayrı audit logger'a yazılır: `LOGIN_OK`, `LOGIN_FAIL`, `LOGIN_BLOCKED`, `USER_CREATED`, `USER_DELETED`, `SSO_LOGIN_OK`, `SSO_DOMAIN_BLOCKED`. |
| **A10** | SSRF | Ollama URL hardcoded `127.0.0.1` — dışarıya istek atılamaz. |

### Ek Güvenlik Önlemleri

| Alan | Uygulanan Önlem |
|---|---|
| **MS SSO Domain Allowlist** | `ALLOWED_DOMAINS` ile yalnızca belirtilen kurumsal domain'lerden giriş kabul edilir |
| **Dosya Yükleme Validasyonu** | 20 MB boyut sınırı, MIME type whitelist (jpg/png/gif/webp/pdf/docx/txt), path traversal önleme |
| **CF-Connecting-IP** | Cloudflare arkasında gerçek IP tespiti — rate limiting doğru IP'ye uygulanır |
| **Press & Hold CAPTCHA** | 3 saniyelik basılı tut — bot saldırılarına karşı, harici servis gerektirmez; başarısız girişte sıfırlanır |
| **Cloudflare Turnstile** | Opsiyonel ek CAPTCHA katmanı |

### Güvenlik Notları
- Şifre kurulum sırasında terminal geçmişine **yazılmaz** (stdin üzerinden Python'a aktarılır)
- `data/users.json` dosyasını dışarıya paylaşmayın
- Production ortamında HTTPS + `secure=True` cookie kullanın
- Microsoft OAuth2 `client_secret` değerini `.nordgpt.conf` dışında tutmayın ve git'e commit etmeyin

---

## 📁 Proje Yapısı

```
NordGpT/
│
├── nordgpt.sh              # Ana başlatıcı & kurulum sihirbazı
├── app.py                  # FastAPI backend
├── models.json             # Kategori bazlı model kataloğu
├── requirements.txt        # Python bağımlılıkları
│
├── static/
│   ├── index.html          # Ana chat arayüzü (SPA)
│   ├── login.html          # Login sayfası (MS SSO + press-and-hold CAPTCHA)
│   └── favicon.svg         # Robot ikonu favicon
│
├── scripts/
│   ├── server-setup.sh     # Sunucu kurulum scripti
│   ├── update.sh           # Güncelleme scripti
│   └── nordgpt.service     # Systemd servis tanımı
│
├── data/
│   ├── users.json          # Kullanıcılar (bcrypt hash'li)
│   ├── chats/              # Sohbet geçmişi (JSON)
│   │   ├── <uuid>.json
│   │   └── ...
│   └── uploads/            # Yüklenen dosyalar (görsel, PDF, DOCX, TXT)
│
├── .nordgpt.conf           # Yapılandırma (kurulum sihirbazı tarafından oluşturulur)
└── .venv/                  # Python sanal ortamı (otomatik oluşturulur)
```

### Sohbet Dosyası Formatı (`data/chats/<uuid>.json`)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "SQL injection nedir?",
  "model": "llama3.1:8b",
  "created_at": "2025-04-06T10:00:00",
  "updated_at": "2025-04-06T10:05:00",
  "temporary": false,
  "created_by": "davut",
  "messages": [
    {
      "role": "user",
      "content": "SQL injection nedir?",
      "timestamp": "...",
      "attachments": ["file_id_1"]
    },
    {
      "role": "assistant",
      "content": "SQL injection...",
      "timestamp": "..."
    }
  ]
}
```

---

## ⚙️ Yapılandırma (.nordgpt.conf)

Kurulum sihirbazı tarafından otomatik oluşturulan yapılandırma dosyası:

```ini
# ── Temel Ayarlar ────────────────────────────────────────────
LANGUAGE=tr
CATEGORY=general
DEFAULT_MODEL=llama3.1:8b
HW_TIER=medium

# ── Microsoft Entra ID / Azure AD SSO (Opsiyonel) ────────────
# Azure Portal → App registrations → Uygulama kimlik bilgileri
MICROSOFT_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MICROSOFT_CLIENT_SECRET=your-client-secret-here
MICROSOFT_TENANT_ID=common          # veya belirli tenant UUID
MICROSOFT_REDIRECT_URI=https://chat.nordisglobal.com/auth/microsoft/callback

# İzin verilen e-posta domain'leri (boş = tüm MS hesapları)
ALLOWED_DOMAINS=sirket.com,baska.com

# Şifre girişini devre dışı bırakır, otomatik MS yönlendirmesi yapar
MICROSOFT_ONLY=true

# ── Cloudflare Turnstile CAPTCHA (Opsiyonel) ─────────────────
# https://dash.cloudflare.com → Turnstile → Site oluştur
TURNSTILE_SITE_KEY=0x4AAAAAAA...
TURNSTILE_SECRET_KEY=0x4AAAAAAA...
```

### Ortam Değişkeni ile Port Değiştirme

```bash
# Farklı port kullan (varsayılan: 7860)
NORDGPT_PORT=8080 ./nordgpt.sh

# Örnekler
NORDGPT_PORT=3000 ./nordgpt.sh   # http://localhost:3000
NORDGPT_PORT=80   ./nordgpt.sh   # http://localhost (root gerekebilir)
```

---

## 🌐 API Referansı

NordGpT'nin FastAPI backend'i şu endpoint'leri sunar:

### Auth
| Method | Endpoint | Açıklama |
|---|---|---|
| `POST` | `/auth/login` | Giriş (rate limited, press-and-hold CAPTCHA) |
| `POST` | `/auth/logout` | Çıkış |
| `GET` | `/auth/me` | Mevcut kullanıcı bilgisi |
| `GET` | `/auth/microsoft` | Microsoft SSO yönlendirmesi |
| `GET` | `/auth/microsoft/callback` | OAuth2 geri dönüş endpoint'i |
| `GET` | `/api/auth/providers` | Kullanılabilir giriş yöntemleri (şifre / SSO) |

### Chat
| Method | Endpoint | Açıklama |
|---|---|---|
| `POST` | `/api/chat` | Mesaj gönder (SSE streaming) |
| `GET` | `/api/history` | Sohbet listesi |
| `GET` | `/api/history/{id}` | Sohbet detayı |
| `PATCH` | `/api/history/{id}` | Sohbet başlığını değiştir |
| `DELETE` | `/api/history/{id}` | Sohbet sil |
| `DELETE` | `/api/history` | Tüm geçmişi sil |

### Dosya Yükleme
| Method | Endpoint | Açıklama |
|---|---|---|
| `POST` | `/api/upload` | Dosya yükle (görsel/PDF/DOCX/TXT, maks 20MB) |
| `GET` | `/api/upload/{file_id}` | Yüklenen dosyayı getir |

### Modeller
| Method | Endpoint | Açıklama |
|---|---|---|
| `GET` | `/api/models` | Yüklü Ollama modelleri |
| `GET` | `/api/catalog` | Model kataloğu (kategori bazlı) |
| `POST` | `/api/pull` | Model indir (SSE progress) |
| `DELETE` | `/api/models/{name}` | Model sil (admin) |

### Kullanıcı Yönetimi (Admin)
| Method | Endpoint | Açıklama |
|---|---|---|
| `GET` | `/api/users` | Kullanıcı listesi |
| `POST` | `/api/users` | Yeni kullanıcı oluştur |
| `DELETE` | `/api/users/{username}` | Kullanıcı sil |

---

## ❓ Sık Sorulan Sorular

**Q: Ollama zaten yüklüyse ne olur?**
A: Script bunu otomatik algılar, yeniden kurmaz. Çalışıp çalışmadığını kontrol eder ve gerekirse başlatır.

**Q: Farklı bir modeli nasıl eklerim?**
A: İki yol var:
```bash
# Terminal üzerinden
./nordgpt.sh pull phi4:14b

# Web arayüzü üzerinden
# ⚙️ Ayarlar → 📦 Modeller → İstediğin modeli seç → ⬇ İndir
```

**Q: Sohbet geçmişim nerede saklanıyor?**
A: `data/chats/` klasöründe JSON dosyaları olarak. Sunucunuzdan dışarı çıkmaz.

**Q: Birden fazla kullanıcı kullanabilir mi?**
A: Evet. Admin panelinden (⚙️ → 👥) yeni kullanıcılar oluşturabilirsiniz. Her kullanıcı sadece kendi sohbetlerini görür.

**Q: GPU olmadan çalışır mı?**
A: Evet, CPU üzerinde çalışır. Küçük modeller (phi3:mini, qwen2.5:0.5b) makul hızda çalışır.

**Q: Yapılandırmayı sıfırlamak istiyorum.**
A: Önce `./nordgpt.sh reset` ile config dosyasını silin, ardından `./nordgpt.sh` ile sihirbazı tekrar başlatın.

**Q: Port 7860 kullanımda, ne yapmalıyım?**
A: `NORDGPT_PORT=8080 ./nordgpt.sh` ile farklı port kullanın.

**Q: macOS'ta "Ollama" izin hatası alıyorum.**
A: Sistem Tercihleri → Gizlilik ve Güvenlik → Ollama'ya izin verin.

**Q: Microsoft SSO nasıl kurulur?**
A: Azure Portal'da uygulama kaydı oluşturun, ardından `.nordgpt.conf` dosyasına `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_TENANT_ID` ve `MICROSOFT_REDIRECT_URI` değerlerini ekleyin. Detaylar için [Microsoft SSO](#-microsoft-sso-entra-id--azure-ad) bölümüne bakın.

**Q: Sadece belirli şirket çalışanlarının giriş yapmasını istiyorum.**
A: `.nordgpt.conf` içinde `ALLOWED_DOMAINS=sirket.com` olarak ayarlayın. Yalnızca bu domain'e ait Microsoft hesapları kabul edilir.

**Q: MICROSOFT_ONLY=true ile admin girişi nasıl yapılır?**
A: `MICROSOFT_ONLY=true` açık olsa bile `/login?fallback=1` adresine giderek şifre formu üzerinden admin girişi yapılabilir.

**Q: Hangi dosya türleri yüklenebilir?**
A: JPG, PNG, GIF, WEBP (görseller), PDF, DOCX ve TXT dosyaları desteklenir. Maksimum boyut 20 MB, mesaj başına en fazla 5 dosya eklenebilir.

**Q: Yüklediğim görseli model görebilir mi?**
A: Yalnızca multimodal modeller görselleri işleyebilir (örn. `llava:7b`, `bakllava:7b`). Standart dil modelleri görsel içeriği göremez; bu durumda görsel görmezden gelinir.

**Q: Press-and-hold CAPTCHA nedir, nasıl çalışır?**
A: Login formunda görünen "Basılı Tut" düğmesine 3 saniye basılı tutulması gereken bir bot engel mekanizmasıdır. Harici bir CAPTCHA servisi gerektirmez ve her başarısız giriş denemesinde sıfırlanır.

**Q: Cloudflare Turnstile ile press-and-hold CAPTCHA birlikte kullanılabilir mi?**
A: Evet. Press-and-hold CAPTCHA her zaman aktiftir. Cloudflare Turnstile, `.nordgpt.conf` içinde `TURNSTILE_SITE_KEY` ve `TURNSTILE_SECRET_KEY` tanımlandığında ek bir katman olarak devreye girer.

---

## 🤝 Katkı

Katkılar memnuniyetle karşılanır!

```bash
# Fork et, klonla
git clone https://github.com/KULLANICI_ADIN/NordGpT.git
cd NordGpT

# Yeni branch oluştur
git checkout -b feature/harika-ozellik

# Değişikliklerini yap ve test et
./nordgpt.sh

# Push et ve PR aç
git push origin feature/harika-ozellik
```

### Geliştirme Ortamı
```bash
# Backend dev modu (hot reload)
source .venv/bin/activate
uvicorn app:app --reload --port 7860

# Ollama ayrı terminalde çalıştır
ollama serve
```

---

## 📄 Lisans

MIT License — Özgürce kullanabilir, değiştirebilir ve dağıtabilirsiniz.

---

<div align="center">

**NordGpT** — Gizliliğini koru, AI'ını yerel çalıştır.

[GitHub](https://github.com/davudows/NordGpT) · [Issues](https://github.com/davudows/NordGpT/issues) · [Discussions](https://github.com/davudows/NordGpT/discussions)

</div>
