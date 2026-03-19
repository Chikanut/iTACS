/* eslint-disable no-undef */
importScripts(
  "https://www.gstatic.com/firebasejs/10.11.1/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.11.1/firebase-messaging-compat.js",
);

firebase.initializeApp({
  apiKey: "AIzaSyBL2_WGaWRRJIGO8yVPoIHFQwFiOqPlnvk",
  appId: "1:786984799876:web:2526cb2018bb9020adfcd1",
  messagingSenderId: "786984799876",
  projectId: "gspp-9e089",
  authDomain: "gspp-9e089.firebaseapp.com",
  storageBucket: "gspp-9e089.firebasestorage.app",
  measurementId: "G-26J77QXPDF",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  const notification = payload.notification || {};
  const title = data.title || notification.title || "Нове сповіщення";
  const body = data.body || notification.body || "";

  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data,
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const targetUrl = buildTargetUrl(data);

  event.waitUntil(
    clients.matchAll({
      type: "window",
      includeUncontrolled: true,
    }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin)) {
          if ("navigate" in client) {
            client.navigate(targetUrl);
          }
          return client.focus();
        }
      }

      return clients.openWindow(targetUrl);
    }),
  );
});

function buildTargetUrl(data) {
  const url = new URL("/", self.location.origin);
  url.searchParams.set("pushKind", data.kind || "group_notification");

  if (data.groupId) {
    url.searchParams.set("pushGroupId", data.groupId);
  }
  if (data.lessonId) {
    url.searchParams.set("pushLessonId", data.lessonId);
  }
  if (data.notificationId) {
    url.searchParams.set("pushNotificationId", data.notificationId);
  }
  if (data.title) {
    url.searchParams.set("pushTitle", data.title);
  }
  if (data.body) {
    url.searchParams.set("pushBody", data.body);
  }

  return url.toString();
}
