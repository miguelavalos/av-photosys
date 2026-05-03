# AV Photosys

Open-source native photo sync client for `AV Photosys`.

This repository is planned as the public home for an `iOS-first` app that syncs user-selected photos to Cloudflare R2 through AV Account backend services.

## Intended product shape

- native SwiftUI iOS app first
- AV Account connection
- local-first selection and queueing
- hosted sync for `Pro` users
- self-hosted compatibility for users who do not want to use the avalsys-hosted backend

## Current state

This repository now includes the native SwiftUI iOS app under `apps/ios`, including local selection, persistent sync queueing, hosted/self-hosted API configuration, remote asset listing, and the foreground hosted upload path.

Public roadmap and setup docs live in:

- [docs/roadmap.md](docs/roadmap.md)
- [docs/install-ios.md](docs/install-ios.md)
- [docs/release-process.md](docs/release-process.md)

Internal avalsys planning may exist elsewhere, but this public repository should remain understandable on its own.

## Repository shape

```text
apps/
  ios/      SwiftUI iOS app
docs/
  install-ios.md
  release-process.md
```

## Local iOS setup

1. Install repo tooling:
   `bun install`
2. Create the local Infisical bootstrap at `.infisical/bootstrap.env`.
3. Resolve the local iOS config through Varlock + Infisical:
   `bun run ios:config`
4. Go to `apps/ios`
5. Generate the Xcode project:
   `xcodegen generate`
6. Open `AVPhotosys.xcodeproj` in Xcode and run the `AVPhotosys` scheme

## Local secrets

This repo now follows the standard avalsys bootstrap pattern:

- `.infisical/bootstrap.env` stays local-only and feeds `scripts/resolve-infisical-bootstrap-env.sh`
- `.env.schema` is the canonical client-config contract
- `apps/ios/Config/Local.xcconfig` is generated locally through `varlock printenv`
- no real tokens or hosted endpoints should be committed

## Third-Party Services

- AV Photosys can operate against an avalsys-hosted backend path or a user-supplied self-hosted endpoint.
- The hosted sync design references Cloudflare R2-backed object storage in the current architecture.
- Signed-in flows depend on AV Account infrastructure outside this public repo.
