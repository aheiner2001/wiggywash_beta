/**
 * Stripe billing for Wiggy Wash.
 *
 * Secrets (firebase functions:secrets:set ...):
 *   STRIPE_SECRET_KEY
 *   STRIPE_PRICE_ID          // quarterly seat price
 *   STRIPE_WEBHOOK_SECRET
 *
 * Create Product "Wiggy Wash location seat" + quarterly Price in Stripe test mode first.
 */
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const Stripe = require('stripe');

initializeApp();
const db = getFirestore();

const stripeSecret = defineSecret('STRIPE_SECRET_KEY');
const stripePriceId = defineSecret('STRIPE_PRICE_ID');
const webhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

function assertAuthed(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
}

async function assertCanBillCompany(uid, companyId) {
  const user = (await db.collection('users').doc(uid).get()).data();
  if (!user) throw new HttpsError('permission-denied', 'No user profile.');
  const role = user.role;
  const ok =
    role === 'platformAdmin' ||
    role === 'superAdmin' ||
    ((role === 'companyManager' || role === 'manager') &&
      user.companyId === companyId);
  if (!ok) throw new HttpsError('permission-denied', 'Not allowed.');
  return user;
}

async function applySubscriptionToCompany(subscription) {
  const companyId = subscription.metadata?.companyId;
  if (!companyId) {
    console.warn('subscription missing companyId metadata', subscription.id);
    return;
  }
  const quantity = subscription.items.data[0]?.quantity ?? 1;
  let billingStatus = 'ok';
  if (subscription.status === 'past_due') billingStatus = 'past_due';
  if (subscription.status === 'canceled') billingStatus = 'canceled';
  if (subscription.status === 'trialing') billingStatus = 'trialing';

  await db.collection('companies').doc(companyId).set(
    {
      purchasedSeats: quantity,
      stripeCustomerId: subscription.customer,
      stripeSubscriptionId: subscription.id,
      billingStatus,
    },
    { merge: true },
  );
}

exports.createCheckoutSession = onCall(
  { secrets: [stripeSecret, stripePriceId] },
  async (request) => {
    assertAuthed(request);
    const companyId = request.data.companyId;
    const quantity = Number(request.data.quantity);
    if (!companyId || !Number.isInteger(quantity) || quantity < 1) {
      throw new HttpsError(
        'invalid-argument',
        'companyId and quantity >= 1 required.',
      );
    }
    await assertCanBillCompany(request.auth.uid, companyId);

    const companyRef = db.collection('companies').doc(companyId);
    const companySnap = await companyRef.get();
    if (!companySnap.exists) {
      throw new HttpsError('not-found', 'Company not found.');
    }
    const company = companySnap.data();
    const stripe = new Stripe(stripeSecret.value());
    const priceId = stripePriceId.value();
    const origin = request.data.returnOrigin;
    if (!origin || typeof origin !== 'string') {
      throw new HttpsError('invalid-argument', 'returnOrigin required.');
    }

    let customerId = company.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.customers.create({
        name: company.name,
        metadata: { companyId },
      });
      customerId = customer.id;
      await companyRef.set({ stripeCustomerId: customerId }, { merge: true });
    }

    if (company.stripeSubscriptionId) {
      const sub = await stripe.subscriptions.retrieve(
        company.stripeSubscriptionId,
      );
      const itemId = sub.items.data[0].id;
      await stripe.subscriptions.update(company.stripeSubscriptionId, {
        items: [{ id: itemId, quantity }],
        proration_behavior: 'create_prorations',
      });
      await companyRef.set(
        { purchasedSeats: quantity, billingStatus: 'ok' },
        { merge: true },
      );
      return { updated: true, purchasedSeats: quantity };
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: customerId,
      line_items: [{ price: priceId, quantity }],
      success_url: `${origin}?billing=success`,
      cancel_url: `${origin}?billing=cancel`,
      client_reference_id: companyId,
      metadata: { companyId },
      subscription_data: { metadata: { companyId } },
    });
    return { url: session.url };
  },
);

exports.createPortalSession = onCall(
  { secrets: [stripeSecret] },
  async (request) => {
    assertAuthed(request);
    const companyId = request.data.companyId;
    if (!companyId) {
      throw new HttpsError('invalid-argument', 'companyId required.');
    }
    await assertCanBillCompany(request.auth.uid, companyId);

    const company = (
      await db.collection('companies').doc(companyId).get()
    ).data();
    if (!company?.stripeCustomerId) {
      throw new HttpsError(
        'failed-precondition',
        'No Stripe customer yet. Buy seats first.',
      );
    }
    const origin = request.data.returnOrigin;
    if (!origin || typeof origin !== 'string') {
      throw new HttpsError('invalid-argument', 'returnOrigin required.');
    }
    const stripe = new Stripe(stripeSecret.value());
    const session = await stripe.billingPortal.sessions.create({
      customer: company.stripeCustomerId,
      return_url: `${origin}?billing=portal`,
    });
    return { url: session.url };
  },
);

exports.stripeWebhook = onRequest(
  { secrets: [stripeSecret, webhookSecret] },
  async (req, res) => {
    const stripe = new Stripe(stripeSecret.value());
    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        req.headers['stripe-signature'],
        webhookSecret.value(),
      );
    } catch (err) {
      console.error('Webhook signature failed', err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    const eventRef = db.collection('stripeEvents').doc(event.id);
    if ((await eventRef.get()).exists) {
      res.json({ received: true, duplicate: true });
      return;
    }

    try {
      switch (event.type) {
        case 'checkout.session.completed': {
          const session = event.data.object;
          if (session.mode === 'subscription' && session.subscription) {
            const sub = await stripe.subscriptions.retrieve(
              session.subscription,
            );
            if (!sub.metadata?.companyId && session.metadata?.companyId) {
              await stripe.subscriptions.update(sub.id, {
                metadata: { companyId: session.metadata.companyId },
              });
              sub.metadata = { companyId: session.metadata.companyId };
            }
            await applySubscriptionToCompany(sub);
          }
          break;
        }
        case 'customer.subscription.updated':
        case 'customer.subscription.deleted': {
          await applySubscriptionToCompany(event.data.object);
          break;
        }
        default:
          break;
      }
      await eventRef.set({ type: event.type, at: Date.now() });
      res.json({ received: true });
    } catch (e) {
      console.error(e);
      res.status(500).send('Handler error');
    }
  },
);
