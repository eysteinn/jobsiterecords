# Job Site Records (jobsiterecords.com) — Backend Services

**Status: placeholder. No services exist yet.**

The MVP is offline-only by promise (see §8.2 of [`docs/high-level-design.md`](../docs/high-level-design.md)). Nothing in this folder is built or deployed during the MVP.

This folder exists now so the repository structure is honest about the intended long-term shape of the project, and so contributors don't put backend code anywhere else by accident.

## What goes here (eventually)

When the paid tier is greenlit (see §14.5 of the design doc), expect roughly:

| Service | Purpose |
| --- | --- |
| `api/` | Public REST/GraphQL API for the web dashboard and synced clients |
| `sync/` | Sync engine — workspace/job replication from mobile clients |
| `auth/` | Authentication, subscription / billing webhook handler |
| `transcribe/` | Async worker for voice-note transcription (cloud/dashboard; not stored in the mobile `items` table) |
| `pdf/` | Server-side PDF report renderer (templates, branding) |

## Rules

- Each service is its own deployable unit with its own README, dependency manifest, and CI lane.
- Services share data contracts via a future `shared/` folder, **not** by reaching into each other's source.
- No service is added until there is a real, scoped reason to build it.
