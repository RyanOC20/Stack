# Supabase Edge Functions

## `extract-assignments`

Powers Cairn's AI ingestion. Accepts a screenshot / photo / pasted webpage URL /
pasted text and returns **candidate** assignments (name, course, type, dueAt,
status, confidence) for the user to review. It does not write to the database —
the Swift client inserts confirmed assignments through the normal RLS-scoped path.

### Request body (POST, JSON)

Provide exactly one source, plus the caller's clock so relative dates resolve:

```jsonc
{
  "imageUrl":   "https://…signed-storage-url…",   // screenshot/photo in Storage
  "imageBase64":"…", "mediaType": "image/png",     // or an inline image
  "pageUrl":    "https://class.example.edu/hw",    // or a public class page
  "text":       "Essay 1 due 10/14 …",             // or pasted text
  "now":        "2026-02-01T09:00:00-08:00",
  "timeZone":   "America/Los_Angeles"
}
```

Response: `{ "assignments": [ { name, course, type, dueAt, status, confidence } ] }`.

### Model

Uses **Gemini 2.5 Flash** (Google AI Studio free tier). Override the model with
the optional `GEMINI_MODEL` secret (e.g. `gemini-2.5-pro`) without a code change.

### Deploy

```sh
supabase secrets set GEMINI_API_KEY=AIza...
# optional: supabase secrets set GEMINI_MODEL=gemini-2.5-pro
supabase functions deploy extract-assignments
```

JWT verification is enforced by the platform; the function additionally rejects
requests without a valid Supabase session so the model key can't be abused.

### Local run

```sh
supabase functions serve extract-assignments
```
