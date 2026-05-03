# AV Photosys Roadmap

This repository tracks the public client for `AV Photosys`.

## Current scope

- native SwiftUI iOS app
- photo-library permission flow
- local-first shell and persistent sync queue
- hosted and self-hosted API configuration
- authenticated remote asset listing
- foreground `prepare-upload -> byte upload -> commit-upload` flow

## Near-term work

1. Validate hosted upload end to end with a real Pro account and real selected photo.
2. Harden retry, delete, duplicate-upload, and account-isolation behavior.
3. Improve sync progress and post-upload remote list refresh.
4. Decide background upload boundaries after foreground sync is reliable.

## Product boundaries for v1

- iOS only
- selective sync, not full automatic device backup
- no Android
- no macOS client yet
- no sharing or social features
- no dependence on private production credentials in the public client
