// Passerelle JavaScript exposée à Flutter (dart:js_interop).
//
// Encapsule l'API Web Push native du navigateur (service worker, permission,
// abonnement) et l'enregistrement de l'abonnement auprès du backend MamaCare.
// Aucune dépendance externe : c'est du JavaScript navigateur standard.
//
// Convention : aucune fonction ne rejette. Elles résolvent toujours avec
// { ok: true, ... } ou { ok: false, error: '...' } afin que le pont
// dart:js_interop n'ait jamais à convertir une exception JavaScript.

(function () {
  if (window.mamaCarePush) return;

  var SW_PATH = 'push-sw/push.js';
  var SW_SCOPE = 'push-sw/';

  function base64UrlToUint8Array(base64String) {
    var padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    var base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    var rawData = window.atob(base64);
    var outputArray = new Uint8Array(rawData.length);
    for (var i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  function isSupported() {
    return (
      'serviceWorker' in navigator &&
      'PushManager' in window &&
      'Notification' in window
    );
  }

  function appRoot() {
    return window.location.origin + window.location.pathname.replace(/[^/]*$/, '');
  }

  function registerServiceWorker() {
    return navigator.serviceWorker.register(appRoot() + SW_PATH, {
      scope: appRoot() + SW_SCOPE,
    });
  }

  function permission() {
    if (!isSupported()) return 'unsupported';
    return Notification.permission;
  }

  function postJson(apiBaseUrl, path, body, token) {
    return fetch(apiBaseUrl + path, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer ' + token,
      },
      body: JSON.stringify(body),
    }).then(function (response) {
      return response.text().then(function (text) {
        if (!response.ok) {
          var message = 'Erreur serveur (' + response.status + ')';
          try {
            var decoded = JSON.parse(text);
            message = decoded.error || decoded.message || message;
          } catch (error) {
            /* réponse non JSON : on garde le message par défaut */
          }
          throw new Error(message);
        }
        try {
          return JSON.parse(text);
        } catch (error) {
          return null;
        }
      });
    });
  }

  function getSubscription() {
    if (!isSupported()) return Promise.resolve(null);
    return registerServiceWorker()
      .then(function (registration) {
        return registration.pushManager.getSubscription();
      })
      .catch(function () {
        return null;
      });
  }

  function currentSubscription() {
    return getSubscription().then(function (subscription) {
      if (!subscription) return { ok: true, active: false };
      var json = subscription.toJSON();
      return { ok: true, active: true, endpoint: json.endpoint };
    });
  }

  // Demande la permission puis enregistre l'abonnement pour CE compte.
  // `token` identifie la patiente : le backend rattache l'abonnement à
  // l'utilisateur du JWT, un compte ne peut donc jamais hériter de
  // l'abonnement d'un autre compte.
  function subscribe(apiBaseUrl, token) {
    if (!isSupported()) {
      return Promise.resolve({
        ok: false,
        error: 'Notifications push non supportées par ce navigateur.',
      });
    }
    if (!token) {
      return Promise.resolve({ ok: false, error: 'Session requise.' });
    }

    return Notification.requestPermission()
      .then(function (result) {
        if (result !== 'granted') {
          throw new Error('Permission de notification refusée.');
        }
        return registerServiceWorker();
      })
      .then(function () {
        return fetch(apiBaseUrl + '/api/push/vapid-public-key', {
          headers: { authorization: 'Bearer ' + token },
        }).then(function (response) {
          if (!response.ok) throw new Error('Clé VAPID indisponible.');
          return response.json();
        });
      })
      .then(function (vapid) {
        if (!vapid || !vapid.publicKey) {
          throw new Error('Clé VAPID absente de la réponse.');
        }
        return registerServiceWorker().then(function (registration) {
          return registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: base64UrlToUint8Array(vapid.publicKey),
          });
        });
      })
      .then(function (subscription) {
        var json = subscription.toJSON();
        return postJson(
          apiBaseUrl,
          '/api/push/register',
          {
            endpoint: json.endpoint,
            p256dh: json.keys.p256dh,
            auth: json.keys.auth,
          },
          token,
        ).then(function () {
          return { ok: true, endpoint: json.endpoint };
        });
      })
      .catch(function (error) {
        return { ok: false, error: error.message || 'Activation impossible.' };
      });
  }

  // Désabonnement « meilleur effort » : même si l'appel réseau échoue on
  // supprime l'abonnement local, sinon l'utilisateur resterait silencieusement
  // ciblé par des notifications qu'il croit avoir désactivées.
  function unsubscribe(apiBaseUrl, token) {
    return getSubscription().then(function (subscription) {
      if (!subscription) return { ok: true, removed: false };
      var endpoint = subscription.endpoint;
      var remote = token
        ? postJson(apiBaseUrl, '/api/push/unregister', { endpoint: endpoint }, token).catch(
            function () {
              return null;
            },
          )
        : Promise.resolve(null);
      return remote
        .then(function () {
          return subscription.unsubscribe();
        })
        .then(function () {
          return { ok: true, removed: true, endpoint: endpoint };
        })
        .catch(function (error) {
          return { ok: false, error: error.message || 'Désactivation impossible.' };
        });
    });
  }

  window.mamaCarePush = {
    isSupported: isSupported,
    permission: permission,
    subscribe: subscribe,
    unsubscribe: unsubscribe,
    currentSubscription: currentSubscription,
  };
})();
