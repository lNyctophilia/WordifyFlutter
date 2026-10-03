// Firebase Messaging Service Worker — Arka planda bildirim dinleyicisi
// Bu dosya, uygulama kapalıyken bile bildirimleri yakalar ve gösterir.

importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBxQrbpgkVPWkou0HiMGGf_cpQ5UK29LQU",
  authDomain: "wp-sayim.firebaseapp.com",
  projectId: "wp-sayim",
  storageBucket: "wp-sayim.firebasestorage.app",
  messagingSenderId: "224740813185",
  appId: "1:224740813185:web:7e8779ae1b54a22c2c6080",
});

// VAPID public key — pushsubscriptionchange handler'ında yeniden abone olmak için gerekli.
// Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
const VAPID_PUBLIC_KEY = 'BOkvHMWfKFEaXrwF-TgJ9KrrJSnNqL3tO966nz5F-esnB6SYZCfSIy6uWe9dvVTKfhPsTZ771DOsGVJY4JeDmio';

const messaging = firebase.messaging();

// ─── SW AKTİVASYON GARANTİSİ ───
// Yeni versiyon deploy edildiğinde beklemeden aktif olması ve
// tüm açık sekmeleri (client'ları) hemen kontrol altına alması için:
self.addEventListener('install', function(event) {
  event.waitUntil(self.skipWaiting());
});
self.addEventListener('activate', function(event) {
  event.waitUntil(clients.claim());
});

// ÇİFT BİLDİRİM ENGELLEYİCİ (Deduplicator)
// Hem bizim 'push' listener'ımız hem de Firebase SDK aynı bildirimi göstermeye çalışır.
// Bu çakışmayı önlemek için showNotification'ı araya girerek eziyoruz.
let lastPushTime = 0;
let lastPushTitle = "";
const originalShowNotification = self.registration.showNotification.bind(self.registration);
self.registration.showNotification = function(title, options) {
  const now = Date.now();
  if (now - lastPushTime < 2000 && lastPushTitle === title) {
    console.log('[firebase-messaging-sw.js] Çift bildirim engellendi:', title);
    return Promise.resolve();
  }
  lastPushTime = now;
  lastPushTitle = title;
  return originalShowNotification(title, options);
};

// iOS'un aboneliği öldürmemesi için, push event'inde her durumda (foreground/background)
// event.waitUntil() içinde showNotification çağrılmak ZORUNDADIR.
self.addEventListener('push', function(event) {
  if (!event.data) {
    // iOS: data gelse de gelmese de showNotification çağrılmalı (budget ihlali olmasın)
    event.waitUntil(
      self.registration.showNotification('WP Sayım', {
        body: 'Yeni bir bildiriminiz var.',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
      })
    );
    return;
  }

  let title = 'WP Sayım';
  let body = 'Yeni bir bildiriminiz var.';
  let notifData = {};

  try {
    const payload = event.data.json();
    title = payload.notification?.title || payload.data?.title || title;
    body = payload.notification?.body || payload.data?.body || body;
    notifData = payload.data || {};
  } catch (e) {
    // JSON parse başarısız — fallback değerleri kullan (iOS budget koruması için yine de göster)
    console.error('[firebase-messaging-sw.js] Push parse hatası:', e);
  }

  const promise = clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
    // Her push alındığında client'lara token yenileme sinyali gönder
    notifyClientsToRefreshToken();

    return self.registration.showNotification(title, {
      body: body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      vibrate: [200, 100, 200],
      requireInteraction: true,
      tag: 'wp-notification-' + Date.now(), // Unique tag
      data: notifData
    });
  });

  event.waitUntil(promise);
});

// ─── iOS PUSH SUBSCRIPTION RENEWAL ────────────────────────────────
// iOS Safari, push subscription'ı sessizce yenileyebilir/geçersiz kılabilir.
// Bu event'i yakalayıp yeni subscription bilgisini client'a iletiyoruz,
// böylece Dart tarafı yeni FCM token'ı Firestore'a kaydedebilir.
self.addEventListener('pushsubscriptionchange', function(event) {
  console.log('[firebase-messaging-sw.js] pushsubscriptionchange tetiklendi!');

  // VAPID key'i base64url → Uint8Array'e çevir
  function urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = atob(base64);
    return Uint8Array.from([...rawData].map(char => char.charCodeAt(0)));
  }

  const applicationServerKey = urlBase64ToUint8Array(VAPID_PUBLIC_KEY);

  event.waitUntil(
    self.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: applicationServerKey
    }).then(function(newSubscription) {
      console.log('[firebase-messaging-sw.js] Yeni subscription alındı:', newSubscription.endpoint);
      return clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
        windowClients.forEach(function(client) {
          client.postMessage({
            type: 'SUBSCRIPTION_CHANGED',
            newEndpoint: newSubscription.endpoint
          });
        });
      });
    }).catch(function(err) {
      console.error('[firebase-messaging-sw.js] Yeni subscription alınamadı:', err);
      return clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
        windowClients.forEach(function(client) {
          client.postMessage({ type: 'SUBSCRIPTION_EXPIRED' });
        });
      });
    })
  );
});

// ─── PUSH ALIMINDA TOKEN CANLI TUTMA ──────────────────────────────
function notifyClientsToRefreshToken() {
  clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
    windowClients.forEach(function(client) {
      client.postMessage({ type: 'TOKEN_REFRESH_NEEDED' });
    });
  });
}

// Bildirime tıklanınca uygulamayı aç
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Bildirime tıklandı:', event);

  // iOS için kritik: Yönlendirme sorunlarını önler
  event.preventDefault();
  event.notification.close();

  // Uygulama zaten açıksa onu odakla, değilse yeni pencere aç
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (const client of clientList) {
        if (client.url.includes('/WP_Sayim') && 'focus' in client) {
          return client.focus();
        }
      }
      // Eğer uygulama arka planda hiç açık değilse, sıfırdan başlat
      return clients.openWindow('/WP_Sayim/');
    })
  );
});
