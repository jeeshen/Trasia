# trasia

A new Flutter project.

## Government Data Used

Trasia includes a Government Data section in the Profile screen. It documents
the official data portals used to support the assignment:

- data.gov.my: Malaysia's official open data portal, used for public transport
  open data and GTFS API references.
- OpenDOSM NextGen: DOSM's open statistics platform, used for demographic,
  economic, price, labour, and social statistics context.
- MYSA Open Government Data: Malaysia Space Agency open data resources, used to
  support the open-data and geospatial-data rationale.
- World Bank Malaysia Data: international benchmark indicators for Malaysia,
  used to compare mobility, environment, population, and development trends.

The app references official Malaysia transit endpoints from data.gov.my for
Rapid KL rail, Rapid KL bus, MRT feeder, and KTMB data.

## Getting Started

Copy `.env.example` to `.env`, then fill in the four public client values.
Never put Supabase secret keys, Stripe secret keys, webhook secrets, SMTP
credentials, or Firebase service-account credentials in `.env`.

Run `flutter pub get`, then `flutter run`.

## Android APK signing

`flutter build apk --release` uses the private signing values in
`android/key.properties` when they are configured. Without that file, local
release builds fall back to the Android debug key so the APK remains
installable for testing; configure a private release keystore before
distributing the app publicly.

## Supabase OTP email confirmation

The app signs users up with Supabase Auth and verifies the 6-digit email OTP
before opening the dashboard. Configure Supabase Auth > Email provider with
Confirm email enabled, and set the confirmation email template to include
`{{ .Token }}`.

For production delivery, configure Brevo as Supabase's custom SMTP provider:

- SMTP host: `smtp-relay.brevo.com`
- Port: `587`
- Username: your Brevo login email
- Password: your Brevo SMTP key
- Sender email: a verified Brevo sender

Ensure the Supabase schema, RLS policies, and authenticated database functions
used by the app are deployed. Profile writes should be limited to safe columns,
with fares, reward redemption, check-ins, and voucher use handled by database
functions. Never put the Brevo SMTP key in `.env` or the Flutter app.

## Stripe sandbox credit top-up

Wallet top-ups use Stripe's native PaymentSheet in test mode. The Edge Function
verifies successful payments directly with Stripe, and the signed webhook
provides recovery when the app closes before confirmation.

The Supabase project must provide the `credit_topups` table and an idempotent
credit function. The repository's `supabase/config.toml` disables gateway JWT
verification only for `stripe-topup`, allowing Stripe to reach the signed
webhook while the function authenticates app requests itself.

Configure these secrets in Supabase **Project Settings > Edge Functions >
Secrets**:

- `STRIPE_SECRET_KEY`: Stripe test secret key beginning with `sk_test_`
- `STRIPE_WEBHOOK_SECRET`: signing secret beginning with `whsec_`

Add the Stripe publishable test key to the Flutter app's `.env` file:

`STRIPE_PUBLISHABLE_KEY=pk_test_...`

Only use a `pk_test_` key in the app. Never put `sk_test_` or `whsec_` values
in `.env` or in Flutter code. The publishable key can also be supplied at
build time with `--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`.

In Stripe **Developers > Webhooks** while test mode is enabled, create an
endpoint at:

`https://ffrhaempwlpqewxjpdea.supabase.co/functions/v1/stripe-topup`

Subscribe it to `payment_intent.succeeded`. Keep
`checkout.session.completed` and `checkout.session.async_payment_succeeded`
enabled if older hosted Checkout sessions may still be used. Use Stripe test card
`4242 4242 4242 4242`, any future expiry, and any CVC.

## Car-Pool push notifications

Before deploying `send-push`, ensure its device-token table is present. Device
tokens are owned and reassigned by the authenticated Edge Function; client
roles have no direct access to the token table. Android uses
`google-services.json`. iOS uses `GoogleService-Info.plist`, Push Notifications
entitlements, and Background Modes for fetch and remote notifications.

Set the complete Firebase service-account JSON as the
`FIREBASE_SERVICE_ACCOUNT_JSON` secret for the `send-push` Edge Function. The
service account needs permission to send Firebase Cloud Messaging messages.
Upload an APNs authentication key in Firebase before testing iOS push delivery.
