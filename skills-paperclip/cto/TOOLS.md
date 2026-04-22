# TOOLS.md

You use the Paperclip API via curl and the `paperclip`, `paperclip-create-agent`, `para-memory-files` skills. Endpoint map and workflows live in `./HEARTBEAT.md`. ADR structure lives in `./ADR-TEMPLATE.md`.

Always include `X-Paperclip-Run-Id` on mutating API calls. Use the `--data-binary @file` idiom for JSON bodies.
