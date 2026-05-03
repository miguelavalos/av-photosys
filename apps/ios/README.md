# AV Photosys iOS

Native SwiftUI iOS app for `AV Photosys`.

## Current scope

This app foundation establishes:

- native SwiftUI project structure
- local config pattern
- photo-library permission flow
- product shell for library, sync queue, and account tabs
- onboarding flow with continue or skip
- real AV Account wiring through the configured account provider
- profile flow with language and theme preferences
- hosted backend reachability check
- authenticated remote asset listing using either a self-hosted token override or the signed-in account session
- persistent local sync queue
- foreground hosted upload flow through `prepare-upload`, byte upload, and `commit-upload`

End-to-end real sync validation with a Pro account is still follow-up work.

## Local setup

1. Install repo tooling from the repo root:
   `bun install`
2. Create `.infisical/bootstrap.env` locally
3. Generate `Config/Local.xcconfig` from the repo root:
   `bun run ios:config`
4. Generate the Xcode project:
   `xcodegen generate`
5. Open `AVPhotosys.xcodeproj` in Xcode.

## Planned next work

- validate end-to-end hosted sync with a real backend
- harden duplicate-upload, delete, retry, and post-upload list refresh behavior
- refine account entitlements and Pro gating
