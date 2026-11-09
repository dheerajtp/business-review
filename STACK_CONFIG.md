# Stack Configuration

Set exactly one stack before using this starter kit.

```text
STACK = react-supabase
```

Supported values:

- `react-mongo`
- `react-postgres`
- `react-supabase`

## Mapping

| STACK | Frontend Rules | Backend / Data Rules |
|---|---|---|
| `react-mongo` | `rules/frontend/CLAUDE_FRONTEND.md` | `rules/backend/CLAUDE_BACKEND_MONGODB.md` |
| `react-postgres` | `rules/frontend/CLAUDE_FRONTEND.md` | `rules/backend/CLAUDE_BACKEND_POSTGRESQL.md` |
| `react-supabase` | `rules/supabase/CLAUDE_REACT_SUPABASE.md` | Supabase-managed backend/data layer |

Do not hardcode the selected stack anywhere in `.ai/`.
