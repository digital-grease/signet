# Data safety declaration — draft answers

Play Console's Data Safety form requires declaring what data the app
collects, shares, and how it's handled. For Signet, the honest
answers are negative across the board. The below is the draft; confirm
against the console's exact wording when filling it out.

## Does your app collect or share any of the required user data types?

**No.**

Signet does not collect any of the following:
- Location (approximate or precise)
- Personal info (name, email, user ID, address, phone number, race,
  sexual orientation, political affiliation, other info)
- Financial info (payment info, purchase history, credit info,
  other financial info)
- Health + fitness (health, fitness)
- Messages (email, SMS / MMS, other messages)
- Photos + videos (photos, videos)
- Audio (voice / sound recordings, music, other audio)
- Files + documents (files + documents)
- Calendar (calendar events)
- Contacts (contacts)
- App activity (app interactions, in-app search history, installed
  apps, other user-generated content, other actions)
- Web browsing (web browsing history)
- App info + performance (crash logs, diagnostics, other app
  performance data)
- Device or other identifiers (device or other identifiers)

## Data processed "ephemerally" that doesn't require declaration

Play's guidance allows ephemeral processing without declaration if:

- Data is processed only in memory.
- Data is not sent off the device.
- Data is not retained for longer than necessary to service the user
  request.

Signet processes the following ephemerally, inside the app, never
transmitted:

- The user-provided **label** for each paired contact (e.g. "Mom").
  Stored on-device in hardware-backed secure storage.
- The cryptographic shared secret for each paired contact. Stored
  on-device in hardware-backed secure storage.
- The rotating verification words, generated from the shared secret
  on-demand. Displayed on screen. Not stored.
- Camera input, during the QR scan step only. Processed entirely
  on-device by the `mobile_scanner` plugin to decode a QR. No frame
  is retained after decoding; no frame is transmitted.
- Clipboard data, only when the user explicitly taps "Paste from
  clipboard" on an import / share screen.

None of this is "collection" in the Play-defined sense because it
doesn't leave the device and doesn't persist beyond what's needed.

## Security practices

- **Data is encrypted in transit**: N/A — the app does not transmit
  data.
- **You can request that data be deleted**: N/A — there is no data
  on our side to delete. User can delete everything by uninstalling
  the app or using the in-app Unpair feature.
- **Data is encrypted at rest**: **Yes.** Paired-contact data
  (labels, metadata, cryptographic secrets) is stored in the
  hardware-backed Android Keystore (StrongBox-backed where
  available). See the app's in-app privacy information and
  `docs/THREAT_MODEL.md` for detail.
- **Independent security review**: at time of v0.2 alpha, no
  external audit has been completed. A security-audit prep pass
  (`docs/THREAT_MODEL.md` + `docs/TEST_VECTORS.md` + `docs/LIMITATIONS.md`
  + reproducible builds) lands in Phase 12. An external audit is a
  v1.0 gate, not a v0.2 claim.
- **Follows Families Policy**: N/A — app is not primary-directed
  at children, and no data is collected from any user regardless
  of age.

## Privacy policy

Linked URL (GitHub renders the markdown at this URL — no Pages setup):
`https://github.com/digital-grease/signet/blob/main/PRIVACY.md`

Source: `PRIVACY.md` at the repo root.
