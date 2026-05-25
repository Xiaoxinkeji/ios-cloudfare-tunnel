# Roadmap

## v0.1 — MVP ✅

- [x] SwiftUI app shell
- [x] Xcode project
- [x] Tunnel dashboard (status, primary action, navigation)
- [x] Tunnel detail page (ID / health / dates / logs)
- [x] Config editor (API Token via Keychain, Account ID, Tunnel ID, Base URL)
- [x] State machine (5 states + edge-detection)
- [x] GitHub Actions unsigned IPA build
- [x] Cloudflare v4 model foundation

## v0.2 — Auth & API Hardening 🚧

- [ ] API Token / Service Token split
- [ ] Keychain credential store v2 (multi-credential, per-account scoping)
- [ ] Cloudflare v4 envelope error handling end-to-end
- [ ] Control backend auth modes (Bearer / mTLS)
- [ ] Retry / transient error policy unified across clients

## v0.3 — DNS & Notifications

- [x] DNS Record list/create/update/delete protocol + client
- [x] Tunnel CNAME convenience helper
- [x] Notification permission flow (in-app pre-prompt + system dialog)
- [x] Edge-detection notification evaluator (down / degraded / token invalid)
- [x] AppDelegate + UNUserNotificationCenterDelegate wiring
- [ ] Hook the evaluator into the polling refresh loop
- [ ] Per-tunnel monitoring opt-in UI
- [ ] Notification settings page

## v0.4 — Control Backend Protocol

- [ ] Define backend OpenAPI contract
- [ ] Runtime status endpoint
- [ ] Start / stop endpoint
- [ ] Logs endpoint (paginated)
- [ ] Healthcheck endpoint
- [ ] Reference backend implementation

## v1.0 — Stable Release

- [ ] Signed release pipeline (Enterprise / Ad Hoc)
- [ ] GitHub Releases auto-publish on tag
- [ ] User guide & screenshots
- [ ] Error recovery polish
- [ ] UI accessibility pass (Dynamic Type / VoiceOver)
- [ ] Localisation (EN / ZH)
