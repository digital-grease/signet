# Content rating questionnaire — draft answers

Google Play uses IARC (International Age Rating Coalition) to assign
per-region content ratings. The questionnaire has ~30 yes/no
questions; answers below are drafts, confirm against the actual
form text when filling out the console.

## Violence

- Does your app contain violence / realistic violence / graphic
  violence? **No.**
- Weapons / combat? **No.**
- Blood / gore? **No.**

## Sexual content

- Nudity / sexual content / suggestive content? **No.**

## Language

- Crude humor / strong language? **No.**

## Controlled substances

- Depiction of use of tobacco / alcohol / drugs? **No.**

## Gambling

- Real-money gambling / simulated gambling? **No.**

## User interaction

- Does your app enable users to interact / communicate with each
  other? **Yes, indirectly.** Signet doesn't send messages between
  users — it helps them verify each other's identity on a call the
  users already have, over external channels. The "pair with
  another person" flow involves QR exchange or package-passing, not
  messaging. Answer "yes" if the form treats QR-based key exchange
  as interaction; answer "no" if it's asking about
  messaging/chat/forum features.
- Can users share personal info? **No** — Signet does not transmit
  or collect user information. The QR and transport-package flows
  exchange ephemeral cryptographic keys, not personal info.
- Unrestricted Internet access? **No** — the app has no INTERNET
  permission.

## Other

- Does your app integrate third-party ad services? **No.**
- Does your app reference real organizations? **No.**
- Location sharing? **No.**
- Personal information collection? **No.**

Expected rating: **Everyone / 3+**.

## Target age group

Primary target audience: **Everyone**, not kid-directed. Signet is
designed to be usable by elderly users (the "grandma test" is
explicit in the threat model) and relevant for journalists, small
business owners, and any adult concerned about impersonation
attacks. It is not specifically for children, but there is nothing
in the app that makes it inappropriate for children — no ads, no
tracking, no user-generated content, no in-app purchases.

## Notes

Signet is genuinely unusual in that its only in-app
"communication" is the pairing handshake and the rotating code
display. There is no free-form text entry other than:
- The contact label (user labels their own pair)
- The paste-field for importing a transport package / backup

Neither of these can leak user-provided content to any external
system, since the app has no network access.

Filling the questionnaire honestly should produce the minimum
possible rating.
