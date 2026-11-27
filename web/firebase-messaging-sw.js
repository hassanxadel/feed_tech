// Shows browser push notifications while the app is closed (Firebase Cloud Messaging).
// Same public web config as lib/firebase_options.dart.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB7qHO9lClP1i3AFlzrHjgguG4imRo7HdY',
  appId: '1:1093508744862:web:1ad84d37ddc2b7a5e4dd8f',
  messagingSenderId: '1093508744862',
  projectId: 'feedtech-fabe2',
  authDomain: 'feedtech-fabe2.firebaseapp.com',
  storageBucket: 'feedtech-fabe2.firebasestorage.app',
});

firebase.messaging();

// Tapping a notification opens (or focuses) the app.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.matchAll({ type: 'window' }).then((list) => {
    for (const c of list) if ('focus' in c) return c.focus();
    return clients.openWindow('/');
  }));
});
