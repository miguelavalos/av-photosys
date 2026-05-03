# Contributing

## Scope

This repository contains the open-source native iOS client for `AV Photosys`.

Contributions are welcome for:

- SwiftUI UI improvements
- local asset selection and queue behavior
- accessibility
- documentation improvements
- tests
- self-hosted compatibility improvements

Please avoid proposing changes that depend on non-public services or credentials.

## Before Opening A PR

1. Keep changes focused and small when possible.
2. Make sure the app still builds locally.
3. Update docs if setup or behavior changes.
4. Do not commit local config, secrets, signing material, or build artifacts.
5. Follow [Private Config And Infisical](docs/private-config-and-infisical.md) for all login, Pro, hosted backend, signing, and release config.

## Pull Requests

- Use clear commit messages.
- Describe user-facing behavior changes.
- Mention any manual verification steps you ran.
- Call out any changes that affect setup, permissions, account flows, or hosted/self-hosted configuration.

## Issues

- Use issues for bugs, usability problems, and well-scoped feature requests.
- For security issues, do not open a public issue. Follow `SECURITY.md`.
