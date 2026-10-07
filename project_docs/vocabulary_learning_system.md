# Yeni Kelime Öğrenim Sistemi (Spaced Repetition & Active Recall)

## 1. Mevcut Sistemin Analizi ve Sorunu
Mevcut sistemde kelimeler doğrusal ve kısa vadeli bir tekrar döngüsüne (7-6-5-4-3-2-1) tabi tutuluyor. Bu yöntem, kelimelerin "Kısa Süreli Bellek"ten (Short-Term Memory) "Çalışma Belleği"ne geçmesini sağlasa da, **"Uzun Süreli Bellek"e (Long-Term Memory)** aktarılmasında başarısız olmaktadır. 

Psikolog Hermann Ebbinghaus'un **"Unutma Eğrisi" (Forgetting Curve)** araştırmalarına göre, insan beyni öğrendiği bir bilginin büyük bir kısmını ilk birkaç gün içinde unutur. Eğer tekrar süreleri hep birbirine yakın ve kısa aralıklı olursa, beyin bu bilgiyi kalıcı olarak kodlamaya gerek duymaz. 3 ay sonra kelimelerin unutulmasının temel bilimsel sebebi budur.

## 2. Bilimsel Çözüm: Aralıklı Tekrar (Spaced Repetition System - SRS)
Kalıcı öğrenme için dünyaca kabul görmüş en etkili yöntem **Aralıklı Tekrar (Spaced Repetition)** ve **Aktif Anımsama (Active Recall)** kombinasyonudur. Anki, Duolingo, SuperMemo gibi platformlar bu algoritmaları kullanır.

Sistem, bir kelimeyi tam unutmak üzereyken tekrar hatırlatmayı hedefler. Her başarılı hatırlamada, o kelimenin bir sonraki tekrar süresi uzar.

### Önerilen Tekrar Aralıkları (SM-2 Algoritması Uyarlaması)
Kelime doğru bilindikçe bir sonraki çıkma süresi katlanarak artar:
- **Adım 1 (Öğrenme):** Aynı gün içinde 1-2 kez.
- **Adım 2:** 1 gün sonra
- **Adım 3:** 3 gün sonra
- **Adım 4:** 7 gün sonra (1 hafta)
- **Adım 5:** 16 gün sonra
- **Adım 6:** 35 gün sonra (1 ay)
- **Adım 7:** 90 gün sonra (3 ay)
- **Adım 8:** 180 gün sonra (6 ay - kalıcı hafıza)

*Eğer kullanıcı bir kelimeyi yanlış bilirse, o kelimenin aşaması sıfırlanır veya bir önceki adıma düşürülür.*

## 3. Soru Mekaniklerinin Geliştirilmesi (Dinamik Zorluk)
Mevcut "Cümleyi göster, altındaki kelimeyi çevir" mantığı beyni fazla zorlamadığı için kalıcılığı düşüktür. Soru tipleri, kullanıcının o kelimeyi tekrar etme seviyesine göre **kademeli olarak zorlaşmalıdır.**

### Aşama 1: Tanıma (Recognition) - *1. ve 2. Tekrarlar*
- **Format:** Cümle içinde kelimenin yeri boş bırakılır (Cloze Deletion).
- **Mekanik:** Boşluğa gelmesi gereken kelime 4 şıklı çoktan seçmeli olarak sorulur.
- **Amaç:** Kelimenin anlamını ve bağlamını zihne oturtmak.

### Aşama 2: Kısmi Üretme (Partial Production) - *3. ve 4. Tekrarlar*
- **Format:** Cümle içinde kelime eksik, altta kelimenin sadece **ilk harfi ve uzunluğu** ipucu olarak verilir.
- **Örnek:** "The _____ (geliştirici) fixed the bug." İpucu: `d_______`
- **Mekanik:** Kullanıcı klavyeden kelimeyi kendi yazar.
- **Amaç:** Aktif anımsama (Active Recall) ile beyni zorlamak.

### Aşama 3: Tam Ustalık (Mastery) - *5. Tekrar ve sonrası*
- **Format:** Hiçbir harf ipucu yok. Sadece Türkçe çevirisi verilir, İngilizcesi istenir (veya tam tersi).
- **Mekanik:** Direkt olarak Input alanına kelimenin tamamı hatasız yazılmalıdır. Ses efektleri ile doğru/yanlış bildirimi burada da devam eder.
- **Amaç:** Kelimeyi tamamen içselleştirmek.

### Aşama 4: Akıllı Hata Geri Bildirimi (Smart Feedback)
Kullanıcı bir kelimeyi yanlış girdiğinde klasik bir "Yanlış" uyarısı yerine pedagojik bir dönüt verilmelidir:
- **Doğru Cevap:** Öncelikle sorunun doğru cevabı gösterilir.
- **Kavram Kargaşasını Önleme (Çapraz Bağlantıların Düzeltilmesi):** Eğer kullanıcının girdiği kelime uygulamadaki 5000+ kelimelik listede bulunuyorsa, bu kelimenin çevirisi de ekranda gösterilir.
- **Örnek:** Soru: "Kabul etmek" (Aranan cevap: *accept*). Kullanıcı yanlışlıkla "*except*" yazdı. Sistem şu uyarıyı verir: *"Yanlış. Doğrusu: **accept**. Senin yazdığın **except** 'hariç' anlamına gelir."*

**Neden Çok Mantıklı?** Bu yöntem dil öğreniminde çok sık yaşanan "Yalancı Eşdeğerler" (False Friends) ve birbirine benzeyen kelimelerin karıştırılması sorununu doğrudan çözer. Kullanıcının "Bu kelime ne demekti o zaman?" şeklindeki kafa karışıklığını anında giderir ve hafızadaki yanlış eşleşmeyi düzelttiği için öğrenme verimini inanılmaz artırır. Kesinlikle uygulamaya değer bir özelliktir.

## 4. Kullanıcı Deneyimi ve Günlük Görevler
Günde sadece 10 kelime sormak yerine, kullanıcının karşısına **Günlük Görev** mantığı çıkmalıdır:
- **Yeni Kelimeler:** 10 Adet (O gün ilk defa görülecekler)
- **Tekrarlar (Review):** Sistem tarafından o gün sorulması gereken (örneğin 3 gün veya 16 gün önce öğrenilmiş) kelimeler.
Bu sayede kullanıcı o gün uygulamaya girdiğinde "Bugün 10 yeni kelime, 25 de tekrar etmem gereken kelime var" şeklinde bir hedef görür.

## 5. Veritabanı ve Uygulama Mimarisine Entegrasyon
Bu sistemi uygulayabilmek için yerel veritabanında (SQLite vb.) kelimelerin tablosuna şu yeni sütunlar eklenmelidir:
- `next_review_date` (DateTime): Kelimenin bir sonraki sorulacağı tarih.
- `step` (Integer): Kelimenin zorluk seviyesi/tekrar adımı (0'dan 8'e kadar).
- `is_learning` (Boolean): Kelimenin yeni mi yoksa tekrar aşamasında mı olduğu.

Gün dönümlerinde veritabanına `SELECT * FROM words WHERE next_review_date <= TODAY` şeklinde bir sorgu atılarak o günün tekrar listesi oluşturulur.

### Bulut Senkronizasyonu (Google ile Giriş ve Firebase)
Uygulamaya **Google ile Giriş (Google Sign-In)** özelliği entegre edilecek ve kullanıcı verileri **Firebase** üzerinde tutulacaktır:
- Kullanıcıların ilerleme durumları (`next_review_date`, `step` vb.) Firebase Firestore veya Realtime Database üzerinde yedeklenecektir.
- Bu sayede kullanıcılar hesaplarına giriş yaptıklarında, cihaz değiştirseler veya uygulamayı silip yükleseler bile **kaldıkları yerden devam edebileceklerdir**.
- Çevrimdışı çalışabilirlik için yerel veritabanı ile Firebase arasında çift yönlü bir senkronizasyon yapısı (offline persistence) kurulacaktır.
