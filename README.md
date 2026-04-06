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
- [Komutlar](#-komutlar)
- [Özellikler](#-özellikler)
- [Model Kategorileri](#-model-kategorileri)
- [Dil Desteği](#-dil-desteği)
- [Güvenlik (OWASP Top 10)](#-güvenlik-owasp-top-10)
- [Proje Yapısı](#-proje-yapısı)
- [Ortam Değişkenleri](#-ortam-değişkenleri)
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

---

## 📸 Ekran Görüntüleri

| Chat Arayüzü | Ayarlar & Model Kütüphanesi | Login |
|---|---|---|
| Dark tema, streaming yanıt | Kategori bazlı model indirme | Güvenli giriş |

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
```
── Donanım ──────────────────────────────────
RAM:     32 GB
CPU:     8 çekirdek
GPU:     NVIDIA RTX 3080
VRAM:    10 GB
Seviye:  ⚡ Orta  — 7-13B modeller önerilir
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
```
Önerilen modeller (donanım: medium | dil: tr):

[1] llama3.1:8b    [tr ✓]  ← zaten yüklü
[2] qwen2.5:7b     [tr ✓]
[3] mistral:7b     [tr ✓]
[4] codellama:13b  [tr ±]
[0] Manuel gir
```

> Türkçe veya Arapça seçildiğinde dil uyumsuz modeller (phi3, tinyllama vb.) otomatik olarak düşük önceliğe alınır.

### Adım 6 — Admin Hesabı Oluşturma
```
── Admin Hesabı Oluştur ──────────────────────
  Sisteme sadece admin yeni kullanıcı ekleyebilir.

? Admin kullanıcı adı [admin]: davut
? Admin şifresi (min 8 karakter): ••••••••
? Şifre tekrar: ••••••••
✔  Admin hesabı oluşturuldu: davut
```

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

# Yapılandırmayı sıfırla (sihirbazı tekrar çalıştır)
./nordgpt.sh reset

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

### Sohbet Yönetimi
| Özellik | Detay |
|---|---|
| **Geçmiş** | Bugün / Dün / Son 7 Gün / Daha Eski grupları |
| **Arama** | Başlığa göre anlık filtreleme |
| **Yeniden Adlandır** | Sohbet başlığını düzenle |
| **Sil** | Tek tek veya toplu silme |
| **Otomatik Başlık** | İlk mesajdan başlık oluşturulur |

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
| **A07** | Auth Failures | **Rate limiting:** IP başına 5 deneme / 5 dakika. 24 saatlik session süresi. Generic hata mesajları (kullanıcı adı enumeration yok). |
| **A09** | Logging Failures | Auth olayları ayrı audit logger'a yazılır: `LOGIN_OK`, `LOGIN_FAIL`, `LOGIN_BLOCKED`, `USER_CREATED`, `USER_DELETED`. |
| **A10** | SSRF | Ollama URL hardcoded `127.0.0.1` — dışarıya istek atılamaz. |

### Güvenlik Notları
- Şifre kurulum sırasında terminal geçmişine **yazılmaz** (stdin üzerinden Python'a aktarılır)
- `data/users.json` dosyasını dışarıya paylaşmayın
- Production ortamında HTTPS + `secure=True` cookie kullanın

---

## 📁 Proje Yapısı

```
NordGpT/
│
├── nordgpt.sh          # Ana başlatıcı & kurulum sihirbazı
├── app.py              # FastAPI backend
├── models.json         # Kategori bazlı model kataloğu
├── requirements.txt    # Python bağımlılıkları
│
├── static/
│   ├── index.html      # Ana chat arayüzü (SPA)
│   └── login.html      # Login sayfası
│
├── data/
│   ├── users.json      # Kullanıcılar (bcrypt hash'li)
│   └── chats/          # Sohbet geçmişi (JSON)
│       ├── <uuid>.json
│       └── ...
│
├── .nordgpt.conf       # Yapılandırma (kurulum sihirbazı tarafından oluşturulur)
└── .venv/              # Python sanal ortamı (otomatik oluşturulur)
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
    { "role": "user",      "content": "SQL injection nedir?", "timestamp": "..." },
    { "role": "assistant", "content": "SQL injection...",     "timestamp": "..." }
  ]
}
```

---

## ⚙️ Ortam Değişkenleri

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
| `POST` | `/auth/login` | Giriş (rate limited) |
| `POST` | `/auth/logout` | Çıkış |
| `GET` | `/auth/me` | Mevcut kullanıcı bilgisi |

### Chat
| Method | Endpoint | Açıklama |
|---|---|---|
| `POST` | `/api/chat` | Mesaj gönder (SSE streaming) |
| `GET` | `/api/history` | Sohbet listesi |
| `GET` | `/api/history/{id}` | Sohbet detayı |
| `PATCH` | `/api/history/{id}` | Sohbet başlığını değiştir |
| `DELETE` | `/api/history/{id}` | Sohbet sil |
| `DELETE` | `/api/history` | Tüm geçmişi sil |

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
A: `./nordgpt.sh reset` komutu ile sihirbazı tekrar çalıştırabilirsiniz.

**Q: Port 7860 kullanımda, ne yapmalıyım?**
A: `NORDGPT_PORT=8080 ./nordgpt.sh` ile farklı port kullanın.

**Q: macOS'ta "Ollama" izin hatası alıyorum.**
A: Sistem Tercihleri → Gizlilik ve Güvenlik → Ollama'ya izin verin.

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
