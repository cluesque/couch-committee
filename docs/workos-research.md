# WorkOS AuthKit research

This is an evaluation, not a description of the app. Couch Committee still signs people in with
Google through `google_sign_in` (see `docs/architecture.md`). We looked at
[WorkOS AuthKit](https://workos.com/authkit) in November 2026 and set it aside for now. This note
keeps what we learned so we don't have to redo it.

We wanted to know whether AuthKit could give us:

- Sign-in with an emailed one-time code, for people who don't want to use Google
- Google and Apple sign-in
- A painless move for existing accounts
- Working sign-in in local development, in ephemeral Superconductor previews, and in production

## How sure we are

On 2026-11-18 we read WorkOS's docs (the Markdown versions listed in
[workos.com/docs/llms.txt](https://workos.com/docs/llms.txt)) and the source of the `workos`
gem, version 10.7.0. Facts below come from those sources. A few things the docs don't settle are
marked **(unconfirmed)**. Each one could be checked in a few minutes with a staging environment.

## What AuthKit offers

### Email codes ("Magic Auth")

- People get a six-digit, single-use code by email, valid for 10 minutes.
  ([docs](https://workos.com/docs/authkit/magic-auth))
- It works through the API, so the form can sit on our own sign-in page. It also works on AuthKit's
  hosted page. In the gem, `create_magic_auth(email:)` sends the code and
  `authenticate_with_magic_auth(code:, email:)` checks it.
- Rate limits: 3 codes a minute per email, and 10 sign-in attempts a minute per email.
  ([docs](https://workos.com/docs/reference/rate-limits))
- Email comes from `access@workos-mail.com` by default. WorkOS
  [says](https://workos.com/docs/email) it can't guarantee delivery from that shared domain, and
  may stop a team's sending if too much of its mail bounces or is marked as spam. For production
  it recommends one of these:
  - a custom email domain ($99 a month), which still sends through WorkOS's shared provider
  - a custom email provider, such as Amazon SES, which uses our own provider account
    ([docs](https://workos.com/docs/authkit/custom-email-providers))
  - sending the emails ourselves, though the app has no mailer today
- In staging, email subjects start with `[STAGING]`.

### Google

- Staging has shared WorkOS Google credentials. Google's consent screen then shows WorkOS's name.
  ([docs](https://workos.com/docs/integrations/google-oauth))
- Production needs our own Google OAuth client. We could reuse the existing "Couch Committee"
  client and add WorkOS's callback URL to its redirect URIs. Google redirects to WorkOS, not to us.
- Even with our own client, Google's account picker says "continue to workos.com". Showing our own
  domain needs a DNS setup through WorkOS. That probably counts as the paid custom domain
  **(unconfirmed)**.
- Signing in through WorkOS updates the user's name and picture from Google every time.
  ([docs](https://workos.com/docs/authkit/social-login))
- WorkOS keeps each sign-in method as an "identity" with an `idp_id`, available from
  `get_user_identities`. ([docs](https://workos.com/docs/reference/authkit/identity)) For Google
  this is very likely Google's `sub`, which is what we store as `users.google_id`. The docs don't
  say so **(unconfirmed)**.

### Apple

- Staging has shared WorkOS Apple credentials, so we can try it without an Apple account.
  ([docs](https://workos.com/docs/integrations/apple))
- Production needs a paid Apple Developer Program membership ($99 a year), plus:
  - an App ID and a Services ID, with `api.workos.com` as the domain and WorkOS's redirect URI as
    the return URL
  - a Sign in with Apple key
  - our Team ID
- People can choose "Hide My Email". To email those relay addresses at all, including sign-in
  codes, WorkOS's "Outbound Email Domains" must be registered under Apple's Sign in with Apple for
  Email Communication. Without that, they can still sign in with Apple, but they get no email.
- A relay address never matches an existing account, so that person ends up with a new, empty
  account. We'd need our own way to link it, or to ask people to share their real email.

### Linking sign-in methods

- WorkOS gives each email address one user, and joins a new sign-in method to that user only when
  the person proves they own the inbox. ([docs](https://workos.com/docs/authkit/identity-linking))
- Email verification is always on, for every sign-in method.
  ([docs](https://workos.com/docs/authkit/email-verification)) Google sign-ins with `gmail.com`
  addresses skip the extra step, because WorkOS trusts Google for those.
  ([docs](https://workos.com/docs/migrate/other-services))
- Otherwise, for example with a Google Workspace address, the sign-in can come back with an
  `email_verification_required` error. WorkOS emails a code, and we finish the sign-in with
  `authenticate_with_email_verification(code:, pending_authentication_token:)`.
  ([docs](https://workos.com/docs/reference/authkit/authentication-errors)) Hosted AuthKit
  handles this for us. Our own page would need to show a "Check your email" step, which can reuse
  the email-code form.
- The gem raises these errors as `WorkOS::APIError` subclasses, with the error's `code` and `body`
  attached.

### Redirect URIs and environments

- Each workspace has a Staging and a Production environment. They're fully separate: users, keys,
  branding, and settings don't carry over, and there's no way to copy users between them.
  ([docs](https://workos.com/docs/authkit/environments))
- Production needs billing details before it unlocks, even on the free tier. Its API key is shown
  only once.
- WorkOS's terms say staging isn't for live users. It's fine for local development and previews.
- The redirect URI is passed with each request, and must be one configured for the app. One must be
  the default. ([docs](https://workos.com/docs/sso/redirect-uris))
- Staging allows `http://` and localhost, including any port (`http://localhost:*/…`).
  Production needs `https://`.
- Wildcards are allowed in both environments, with these rules:
  - only one `*`, in the left-most label, like `https://*.example.com/callback`
  - it matches a single label, not `a.b.example.com`
  - not on a public-suffix domain, so `*.fly.dev` is out
  - a wildcard URI can't be the default
- Sign-out URIs follow the same rules, and one should be set as the default.
  ([docs](https://workos.com/docs/authkit/sessions))

### The hosted sign-in page

- Showing it inside an iframe isn't supported. A request to allow it,
  [workos/authkit#70](https://github.com/workos/authkit/issues/70), is still open. Google's and
  Apple's own pages can't be framed either.
- Branding covers logo, colors, and custom CSS. Showing it on our own domain needs the paid custom
  domain. ([docs](https://workos.com/docs/custom-domains))

### Ruby gem

- Gem `workos`, version 10.7.0 (2026-11-13), needs Ruby 3.3 or newer. Its only dependencies are
  `jwt`, `logger`, and `zeitwerk`. It uses plain `Net::HTTP`.
- The methods we'd use, all on `WorkOS.client.user_management`:
  - `get_authorization_url(redirect_uri:, provider:, state:)` builds the URL locally, with no
    request. `provider` is `"authkit"`, `"GoogleOAuth"`, or `"AppleOAuth"`.
  - `authenticate_with_code(code:)` finishes a Google, Apple, or hosted sign-in.
  - `create_magic_auth` and `authenticate_with_magic_auth` handle email codes.
  - `authenticate_with_email_verification` handles the extra verification step.
  - `get_user_identities(id:)` lists a user's sign-in methods.
  - `create_user(email:, email_verified:, external_id:)` creates a user ahead of time.
  - `get_logout_url` and `revoke_session` end a WorkOS session.
- Some code examples in WorkOS's docs still use older names, such as
  `WorkOS::UserManagement.authorization_url`. Go by the gem.
- We don't have to keep WorkOS's tokens. We can check the sign-in once, then use our own `Session`
  row and cookie as we do today.

### Price

- AuthKit is free up to 1 million monthly active users, and staging is never billed. Google and
  Apple sign-in are included. ([pricing](https://workos.com/pricing))
- A custom domain costs $99 a month. It keeps billing while it's configured, even if it isn't
  used.

### Testing

- WorkOS recommends [WorkOS Emulate](https://github.com/workos/emulate), a local copy of its API,
  for most tests. ([docs](https://workos.com/docs/authkit/testing)) It's a Node package, but
  each release also ships standalone binaries, so it wouldn't need a Node toolchain. It would
  still be a separate server for tests and CI to start.
- What fits this repo better: wrap the gem in a small client in `app/services/` with a swappable
  adapter, as `Tmdb` does. Then add a `test/support/fake_workos.rb` in the style of
  `fake_google.rb` and `fake_tmdb.rb`.

## Superconductor previews

- Each preview runs at its own host, like `ti-…-web.sandbox.superconductor.com` (from
  `AGENT_WEB_HOST`), shown in an iframe on superconductor.com.
- Google won't accept wildcard redirect URIs. So today's Google sign-in can't work in a preview
  unless its exact host is registered with Google first.
- With AuthKit, email codes would work in previews with no redirect setup at all, since the whole
  exchange stays on our page.
- Google and Apple in previews would need a staging redirect URI
  `https://*.sandbox.superconductor.com/…`.
  - The preview host is a single label, so it fits the wildcard rules.
  - It's blocked if `sandbox.superconductor.com` is on the public suffix list. We couldn't check,
    because the list was blocked by network policy **(unconfirmed)**.
  - The wildcard would also accept other people's Superconductor sandboxes. Only staging accounts
    would be exposed, but it's a trade-off.
  - The redirect has to leave the iframe, which the sign-in button already does in development.
- If the session cookie doesn't stick inside the preview frame, Superconductor suggests
  `SameSite=None; Secure` in development only.
  ([docs](https://www.superconductor.com/docs/implementations/live-preview))

## The approach we'd take

If we pick this up again, this is the plan we'd recommend.

1. **Keep our own sign-in page**, with three choices:
   - "Email me a code", a form that uses Magic Auth through the API
   - "Continue with Google" and "Continue with Apple", which redirect straight to that provider
     through WorkOS

   When WorkOS asks for email verification, show a "Check your email" code step. This skips the
   WorkOS-branded hosted page and the custom domain fee.
2. **Keep our own sessions.** On success, create the same `Session` row and signed cookie as now.
   Existing sessions stay valid, so nobody is signed out when we switch.
3. **Move accounts over lazily, with no import script.**
   - Add a unique, nullable `workos_user_id` to `users`.
   - On sign-in, find the user in this order:
     1. by `workos_user_id`
     2. by `google_id`, using the Google identity's `idp_id`
     3. by verified email, claiming a user with no `workos_user_id` yet
     4. otherwise, create one along with their "Just Me" list, as now
   - People added to a list by email but never signed in are claimed the same way they are today.
     This also matches WorkOS's own advice for social sign-in users: they're linked by email.
   - Remove `google_sign_in` once everyone has signed in.
4. **Use two WorkOS environments.**
   - Staging for local development and previews, with keys in development credentials and a
     Superconductor secret.
   - Production for Fly, with its redirect URI on `couch-committee.fly.dev` and its keys in
     `config/credentials.yml.enc`, like TMDB's.
5. **Start with email codes and Google.** Add Apple once there's an Apple Developer account and a
   plan for hidden emails.

## Risks and open questions

- **One more outside service.** Sign-in would depend on WorkOS being up, where today it depends
  only on Google.
- **Code emails** from WorkOS's shared domain have no delivery guarantee. Before relying on email
  codes, plan on a custom email provider or the $99-a-month custom domain.
- **Hidden Apple emails** leave someone with an empty account unless we build a way to link it.
- **To check in staging before building:**
  - that a Google identity's `idp_id` is Google's `sub`
  - that WorkOS accepts `https://*.sandbox.superconductor.com/…` as a redirect URI
  - whether showing our own domain on Google's account picker needs the paid custom domain

## The alternative without a vendor

- **Email codes:** Action Mailer, plus a mail provider such as Postmark or Resend.
- **Apple:** `omniauth-apple`.
- **Google:** keep `google_sign_in`.

That's more pieces to build and maintain, especially Apple. It isn't cheaper either, since reliable
code emails need a mail provider with or without WorkOS. Its one advantage is not depending on
WorkOS.
