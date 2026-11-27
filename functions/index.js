// Sends a phone push for every in-app notification. Needs the Blaze plan:
//   cd functions && npm install && cd .. && firebase deploy --only functions --project feedtech-fabe2
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.pushNotification = onDocumentCreated('notifications/{id}', async (event) => {
  const n = event.data?.data();
  if (!n) return;
  const user = await getFirestore().doc(`users/${n.to}`).get();
  const tokens = user.get('fcmTokens') || [];
  if (tokens.length === 0) return;
  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: 'فيد تك', body: n.text },
    webpush: { fcmOptions: { link: '/' }, notification: { icon: '/icons/Icon-192.png', dir: 'rtl', lang: 'ar' } },
  });
  // Forget tokens of browsers that uninstalled or blocked notifications.
  const dead = tokens.filter((_, i) => !res.responses[i].success &&
    ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']
      .includes(res.responses[i].error?.code));
  if (dead.length) await user.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
});
