# AV Photosys Release Process

This document defines the public release checks for `AV Photosys`.

Release topics:

- public repo release preparation
- config and environment validation
- App Store preparation
- hosted backend readiness check
- self-hosted documentation check
- post-release verification

Initial release rules:

- do not commit local client config
- do not commit private infrastructure values
- keep hosted backend behavior explicit in docs
- keep the first public release scoped to iOS and selective sync
- generate production config through Infisical with `bun run ios:config:production`
- run the tracked-file secret scan from `docs/private-config-and-infisical.md` before push
