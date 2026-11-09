# Project Context

## Purpose

Persistent context for this project.

This file should contain stable, verified architectural knowledge. It is not a substitute for inspecting the current repository.

## Current Status

This project is new / being initialized.

Do not assume an architecture until it has been verified or explicitly decided.

## Stack

- Frontend: React 19 + Vite, plain JavaScript (.jsx/.js, no TypeScript), plain CSS tokens (`web/`)
- Backend: Supabase only (RPC + one Edge Function `create-business-admin`)
- Database: Supabase Postgres, RLS as the authorization boundary (`supabase/migrations/`)
- Authentication: Supabase Auth email/password; roles in `public.profiles`
- State management: local state + `useAsync` hook (`web/src/lib/useAsync.js`)
- Testing: SQL RLS/RPC assertions in `supabase/tests/`; browser checks done manually
- Deployment: Vercel (Root Directory `web`, SPA rewrite in `web/vercel.json`); Supabase migrations/Edge Function via Supabase CLI

## Architecture

Not established yet.

Populate this section only with verified project information.

## Repository / Application Structure

Not established yet.

## Important Existing Patterns

Not established yet.

## API Architecture

Not established yet.

## Database Architecture

Not established yet.

## Authentication / Authorization

Not established yet.

## Localization

Not established yet.

## Testing

Not established yet.

## Development Commands

`cd web && npm run dev | build`. DB tests: see README.md.

## Important Integrations

Not established yet.

## Stable Project Constraints

Only constraints explicitly confirmed by the project owner or verified from the project belong here.

## Context Maintenance

When stable architectural facts are discovered:
- Add them here.
- Keep them concise.
- Do not add temporary task progress.
- Do not add secrets.
- Correct outdated information when the architecture changes.

The actual repository remains the ultimate source of truth.
