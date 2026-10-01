// Service worker de notifications push (MamaCare).
//
// Reçoit les messages envoyés par le backend via le protocole Web Push
// standard (VAPID + chiffrement aes128gcm) et affiche une notification
// système, même lorsque l'application n'est pas ouverte.

self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

// Les icônes vivent à la racine de l'application, le scope du worker est
// /push-sw/ : on remonte d'un niveau pour construire des URL absolues.
function assetUrl(relative) {
  return new URL('../' + relative, self.registration.scope).toString();
}

self.addEventListener('push', function (event) {
  var title = 'MamaCare';
  var body = 'Vous avez un nouveau rappel.';
  var url = '/';

  if (event.data) {
    try {
      var parsed = event.data.json();
      if (parsed && typeof parsed === 'object') {
        title = parsed.title || title;
        body = parsed.body || body;
        url = parsed.url || url;
      }
    } catch (error) {
      body = event.data.text();
    }
  }

  event.waitUntil(
    self.registration.showNotification(title, {
      body: body,
      icon: assetUrl('icons/Icon-192.png'),
      badge: assetUrl('icons/Icon-192.png'),
      tag: 'mamacare-rappel',
      renotify: true,
      data: { url: url },
    }),
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var target = (event.notification.data && event.notification.data.url) || '/';

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (clientList) {
        for (var i = 0; i < clientList.length; i += 1) {
          var client = clientList[i];
          if ('focus' in client) {
            client.navigate(target);
            return client.focus();
          }
        }
        return self.clients.openWindow(target);
      }),
  );
});
