# iOS Cloudflare Tunnel

An iOS control-plane app for Cloudflare Tunnel management.

> This app does not run `cloudflared` locally on iOS yet.
> It manages Cloudflare Tunnel metadata through the Cloudflare v4 API and delegates start/stop operations to your own control backend.

## Current Status

- ✅ SwiftUI iOS app
- ✅ Xcode project
- ✅ Tunnel status dashboard
- ✅ Tunnel detail page
- ✅ Cloudflare Tunnel v4 models
- ✅ DNS record models + API client
- ✅ Local notification foundation (permission flow + edge-detection scheduler)
- ✅ GitHub Actions unsigned IPA build
- 🚧 Auth layer v2 (API Token / Service Token split, Keychain v2)
- 🚧 Release workflow (tag-driven GitHub Releases)

## Download

### Option A — GitHub Actions Artifact (current)

1. Open the [Actions](../../actions) tab
2. Pick the latest successful **Build Unsigned IPA** run
3. Scroll to **Artifacts** at the bottom of the page
4. Download `CloudfareTunnel-unsigned`

> Artifacts expire after 30 days.

### Option B — GitHub Releases (coming soon)

Tag-driven release workflow will publish IPAs to the [Releases](../../releases) page. See `ROADMAP.md`.

## Install on iPhone

The IPA is **unsigned**. You need to sign it with your own certificate before it will install on a device.

Recommended tools:

- Apple Configurator 2
- Sideloadly
- AltStore
- Enterprise / Developer certificate pipeline

## Architecture

```
iOS App
├── SwiftUI UI
├── Cloudflare v4 API Client
│   ├── Tunnel metadata
│   ├── Tunnel connections
│   ├── Tunnel token
│   └── DNS records
└── Control Backend Client
    ├── Start tunnel
    ├── Stop tunnel
    └── Runtime status
```

## Why a Control Backend?

Cloudflare v4 API can query tunnels, connections, tokens, and remote configuration.

It does **not** provide an official "start tunnel process" or "stop tunnel process" endpoint — `cloudflared` initiates outbound connections itself.

So start/stop actions need to be handled by:

- your own backend, or
- a server-side agent that runs alongside `cloudflared`, or
- a service manager (systemd / launchd / k8s deployment) controlling the daemon.

## Roadmap

See [`ROADMAP.md`](./ROADMAP.md).

## License

MIT (see `LICENSE`).
