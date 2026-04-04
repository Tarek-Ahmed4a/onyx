importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

const firebaseConfig = {
  apiKey: "AIzaSyCLIa78EbsgPXypBCrlFJXYdKXOVr2kwCw",
  appId: "1:179900082745:web:bc72e7c0f76ff016b0bbe8",
  messagingSenderId: "179900082745",
  projectId: "onyx-c4702",
  authDomain: "onyx-c4702.firebaseapp.com",
  storageBucket: "onyx-c4702.firebasestorage.app"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  return self.registration.showNotification(notificationTitle,
    notificationOptions);
});
