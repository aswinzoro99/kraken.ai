# Kraken API

A small Dart server ([shelf](https://pub.dev/packages/shelf)) for the jobs
the app can't be trusted to do itself. Firebase (sign-in, Firestore) does
everything else directly from the app.

| Endpoint | What it does |
| --- | --- |
| `POST /v1/auth/code` `{email}` | Emails a 6-digit code (10 minutes, 5 tries, one resend per 30 s). 204. |
| `POST /v1/auth/verify` `{email, code}` | Checks the code; creates the Firebase account the first time; returns `{customToken, newUser}` for `signInWithCustomToken`. |
| `POST /v1/account/delete` | With `Authorization: Bearer <Firebase ID token>`: deletes the profile, then the account. 204. |
| `GET /healthz` | `ok` |

Errors are JSON `{"error": "<code>"}`: `invalid_email`, `resend_too_soon`
(`retryAfterSeconds`), `wrong_code` (`attemptsLeft`), `expired`,
`too_many_attempts`, `no_code_requested`, `unauthenticated`, `rate_limited`
(20 sign-in requests a minute per address), `email_failed`, `internal`.

Codes are stored only as a peppered HMAC, under a hash of the email, in
`authCodes/` (closed to apps by `firebase/firestore.rules`).

## Run it locally (no accounts needed)

The Firebase emulators run a pretend project, `demo-kraken`:

```sh
# terminal 1: Auth and Firestore emulators (needs Node and Java)
cd firebase && npx -y firebase-tools@15.37.0 emulators:start --only auth,firestore

# terminal 2: the API on :8081; codes are printed instead of emailed
cd server
PROJECT_ID=demo-kraken \
FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
FIRESTORE_EMULATOR_HOST=localhost:8080 \
dart run bin/server.dart
```

## Tests

```sh
dart test                                    # unit tests, no emulators
KRAKEN_EMULATORS=1 dart test --tags emulator # the full sign-in path, emulators running
```

## Configuration

| Variable | |
| --- | --- |
| `PROJECT_ID` | Firebase project, e.g. `kraken-dev` |
| `CODE_PEPPER` | Secret for code hashes (Secret Manager in production) |
| `MAILER` | `resend` (default) or `console` (default on emulators) |
| `RESEND_API_KEY`, `MAIL_FROM` | Resend key and sender, e.g. `Kraken <codes@mail.your-domain.com>` |
| `FIREBASE_AUTH_EMULATOR_HOST`, `FIRESTORE_EMULATOR_HOST` | Set to use the emulators |
| `SERVICE_ACCOUNT_JSON` | Only to run against real Firebase from a laptop |

**Resend needs a domain.** It only sends from a domain verified in its
dashboard (DKIM and SPF DNS records); until there is one, it can't email
your friends.

## Deploy to Cloud Run (when the Firebase project exists)

```sh
gcloud config set project kraken-dev
gcloud services enable run.googleapis.com iamcredentials.googleapis.com secretmanager.googleapis.com

# Secrets
printf '%s' "$(openssl rand -hex 32)" | gcloud secrets create code-pepper --data-file=-
printf '%s' "re_..."                    | gcloud secrets create resend-api-key --data-file=-

# The service signs custom tokens as itself, so it needs this role on itself
SA=$(gcloud iam service-accounts list --filter="Compute Engine default" --format='value(email)')
gcloud iam service-accounts add-iam-policy-binding "$SA" --member="serviceAccount:$SA" \
  --role=roles/iam.serviceAccountTokenCreator
gcloud projects add-iam-policy-binding kraken-dev --member="serviceAccount:$SA" --role=roles/firebaseauth.admin
gcloud projects add-iam-policy-binding kraken-dev --member="serviceAccount:$SA" --role=roles/datastore.user

gcloud run deploy kraken-api --source . --region asia-south1 \
  --allow-unauthenticated --max-instances 1 --min-instances 0 \
  --set-env-vars PROJECT_ID=kraken-dev,MAIL_FROM='Kraken <codes@mail.your-domain.com>' \
  --set-secrets CODE_PEPPER=code-pepper:latest,RESEND_API_KEY=resend-api-key:latest
```

Add a $1 budget alert on the billing account. At this size it stays in
Cloud Run's free tier.
