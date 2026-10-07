# Yeni Kelime Öğrenim Sistemi - Arayüz (UI/UX) Tasarım Rehberi

Bu belge, `vocabulary_learning_system.md` dosyasında belirtilen aralıklı tekrar (Spaced Repetition) ve aktif anımsama (Active Recall) sistemlerinin kullanıcı arayüzü (UI) ve kullanıcı deneyimi (UX) vizyonunu tanımlar.

## 1. Genel Tasarım Dili ve Atmosfer
- **Modern ve Temiz (Minimalist):** Kullanıcının dikkatini dağıtacak gereksiz öğelerden kaçınılmalı, odak tamamen kelimeye ve cümleye verilmelidir.
- **Renk Paleti:** Göz yormayan, modern renkler. Örneğin; koyu modda (Dark Mode) lacivert/koyu gri arka planlar, neon detaylar (başarı için canlı yeşil, uyarı/hata için pastel kırmızı, ilerleme için elektrik mavisi veya mor).
- **Glassmorphism:** Kart tasarımlarında hafif saydamlık ve bulanık arka plan efektleri (blur) ile premium bir hissiyat.
- **Mikro-Animasyonlar:** Doğru cevaplarda tatmin edici büyüme/küçülme (scale) animasyonları, yanlış cevaplarda hafif titreme (shake) efekti.
- **Haptik Geri Bildirim:** Telefondaki titreşim motorunun doğru/yanlış durumlarda hafifçe kullanılması (başarı için yumuşak bir tıklama, hata için çift titreşim).

## 2. Ekranlar ve Akışlar

### 2.1. Ana Ekran (Dashboard)
Kullanıcı uygulamayı açtığında onu "Günlük Görevleri" karşılamalıdır.
- **Üst Kısım (Header):** Kullanıcı profili, mevcut seri (streak) alevi 🔥 ve toplam öğrenilen kelime sayısı.
- **Günlük Görev Kartı (Büyük Odak Noktası):**
  - "Bugünün Hedefi" başlığı.
  - İki adet dairesel veya yatay ilerleme çubuğu (Progress Bar):
    - 🔵 **Yeni Kelimeler:** 0 / 10
    - 🟢 **Tekrarlar (Review):** 0 / 25
  - Ortada büyük, dikkat çekici, gradient renkli bir **"Güne Başla (Start)"** butonu.
- **Alt Kısım:** İstatistikler, öğrenme grafikleri (haftalık aktivite) ve genel durum.

### 2.2. Öğrenme / Test Ekranı (Session UI)
Görev başladığında geçilen ana etkileşim ekranı.
- **Üst Bar:** O anki seansın (örn: 35 kelime) ilerleme çubuğu. Minimal ve ince bir çizgi halinde dolmalı. Ayrıca bir "Durdur/Çık" butonu.
- **Ana İçerik Alanı (Ortalanmış):** Soru tipine göre değişen dinamik bir kart (Flashcard) tasarımı. Kart geçişlerinde sağa/sola kayma (swipe) veya sayfa çevirme (flip) animasyonları olmalı.

#### Soru Tipi A: Tanıma (Aşama 1 & 2)
- **Kart İçeriği:** Ortada büyük bir fontla İngilizce cümle. Cümledeki hedef kelime boş bırakılmış (örn: `The _______ fixed the bug.`).
- **Seçenekler (Alt Kısım):** 4 adet buton (2x2 grid yapısında).
  - Butonlar yuvarlak köşeli, şık gölgeli olmalı.
  - Dokunulduğunda hafifçe içe çökme (press) efekti.

#### Soru Tipi B: Kısmi Üretme (Aşama 3 & 4)
- **Kart İçeriği:** Cümle ve boşluk. Boşluğun altında zarif bir ipucu (örn: `d _ _ _ _ _ _ _ _`).
- **Girdi Alanı (Input):** Büyük, ekrana odaklı bir metin kutusu. Kullanıcı yazmaya başladıkça harfler kutucuklara veya altı çizili alanlara dolmalı.
- **Klavye:** Otomatik olarak açılır ve kelime tamamlandığında "Gönder/Kontrol Et" butonu belirginleşir.

#### Soru Tipi C: Tam Ustalık (Aşama 5+)
- **Kart İçeriği:** Sadece Türkçe çeviri (örn: "Geliştirici").
- **Girdi Alanı:** Hiçbir ipucu barındırmayan, sade ve şık bir metin alanı. Altında silik bir "İngilizcesini yazın..." placeholder'ı.

### 2.3. Akıllı Hata Geri Bildirimi (Smart Feedback) Popup'ı
Kullanıcı yanlış bir cevap verdiğinde anında devreye girer.
- **Animasyon:** Soru kartı kırmızıya çalarak hafifçe titrer.
- **Geri Bildirim Kartı:** Ekranın altından veya kartın hemen altından yukarı doğru kayarak (slide-up) açılır.
- **Tasarım:**
  - Sol tarafta kırmızı bir "X" veya ünlem ikonu.
  - **Ana Mesaj:** "Yanlış Cevap. Doğrusu: **developer**"
  - **Akıllı Uyarı Bölgesi (Eğer kavram kargaşası varsa):** Sarımsı/Turuncu bir uyarı kutusu içinde: "Senin yazdığın *designer* kelimesi 'tasarımcı' anlamına gelir."
  - **Aksiyon Butonu:** Alt kısımda geniş bir "Anladım (Devam Et)" butonu. Kullanıcı bunu onaylamadan sonraki soruya geçemez.

## 3. Başarı ve Tamamlama Ekranı (Session Complete)
Seans bittiğinde kullanıcıyı ödüllendiren bir ekran.
- **Görsel Şölen:** Ekranda konfetiler patlar veya benzeri tatmin edici bir 3D/Lottie animasyonu oynar.
- **İstatistikler:**
  - Öğrenilen yeni kelimeler.
  - Doğruluk oranı (Örn: %85).
  - Kazanılan XP veya puan.
- **Mesaj:** "Harika iş çıkardın! Yarın görüşmek üzere."
- **Aksiyon:** "Ana Sayfaya Dön" butonu.

## 4. Kullanıcı Deneyimi (UX) İpuçları
- **Hız ve Akıcılık:** Doğru cevap verildiğinde ekstra bir "İleri" butonuna basmaya gerek kalmadan, 0.5 saniyelik bir yeşil onay animasyonunun ardından sistem otomatik olarak diğer soruya geçmelidir.
- **Kesintisiz Deneyim:** Klavye gereken aşamalarda (Kısmi Üretme ve Tam Ustalık), input alanı her zaman otomatik olarak seçili (auto-focus) gelmeli ve klavye hazır beklemelidir.
- **Mikro-Kopyalar (Microcopy):** Kullanıcıyı motive edici ufak yazılar eklenmelidir ("Harika gidiyorsun!", "Bunu da bildin!" gibi).
