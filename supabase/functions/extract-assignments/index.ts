// extract-assignments — Cairn AI ingestion Edge Function (Google Gemini).
//
// Reads a screenshot / photo / pasted webpage URL / pasted text from a class
// page or Canvas and returns *candidate* assignments for the user to review.
// Extraction only — it never writes to the database. Confirmed assignments are
// inserted by the Swift client through the normal RLS-scoped PostgREST path.
//
// Uses the current free-tier Flash model (gemini-flash-latest). Overridable via GEMINI_MODEL.
//
// Deploy:  supabase functions deploy extract-assignments
// Secret:  supabase secrets set GEMINI_API_KEY=AIza...
// JWT is verified by the platform (verify_jwt = true); we additionally resolve
// the caller so anonymous requests can't burn the model key.

import { GoogleGenAI, type Part, Type } from "npm:@google/genai@^1.0.0";
import { createClient } from "npm:@supabase/supabase-js@^2.48.0";
import { encodeBase64 } from "jsr:@std/encoding/base64";
import {
  assertOwnStorageUrl,
  assertPublicHttpUrl,
  decodedBase64Size,
  isAllowedImageMediaType,
  MAX_FETCH_BYTES,
  MAX_IMAGE_BYTES,
} from "./security.ts";

// Rolling alias for the current free-tier Flash model, so a Google model
// retirement doesn't break us. Override with the GEMINI_MODEL secret if desired.
const DEFAULT_MODEL = "gemini-flash-latest";

const ASSIGNMENT_TYPES = [
  "Homework",
  "Report",
  "Essay",
  "Presentation",
  "Quiz",
  "Exam",
];

const ASSIGNMENT_STATUSES = [
  "Not Started",
  "In Progress",
  "Completed",
];

// Structured-output schema. Enum literals match the Postgres enums exactly so
// the client's AssignmentDTO maps them without a fallback.
const RESULT_SCHEMA = {
  type: Type.OBJECT,
  required: ["assignments"],
  properties: {
    assignments: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        required: ["name", "course", "type", "dueAt", "status", "confidence"],
        propertyOrdering: ["name", "course", "type", "dueAt", "status", "confidence"],
        properties: {
          name: { type: Type.STRING },
          course: { type: Type.STRING },
          type: { type: Type.STRING, enum: ASSIGNMENT_TYPES },
          dueAt: { type: Type.STRING, description: "ISO 8601 date-time in the student's time zone" },
          status: { type: Type.STRING, enum: ASSIGNMENT_STATUSES },
          confidence: { type: Type.NUMBER },
        },
      },
    },
  },
};

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ExtractRequest {
  imageUrl?: string; // short-lived signed Storage URL
  imageBase64?: string; // raw base64, no data: prefix
  mediaType?: string; // e.g. "image/png" (required with imageBase64)
  pageUrl?: string; // a public class-page URL to fetch
  text?: string; // pasted syllabus / assignment text
  now?: string; // caller's current time, ISO 8601
  timeZone?: string; // IANA tz, e.g. "America/Los_Angeles"
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function systemPrompt(now: string, timeZone: string): string {
  return [
    "You extract graded academic assignments from class pages, syllabi, and Canvas screenshots.",
    "Return ONLY assignments that a student must complete and hand in (homework, reports, essays, presentations, quizzes, exams). Ignore lecture topics, readings without a deliverable, office hours, and administrative notes.",
    `The student's current date-time is ${now} in time zone ${timeZone}. Resolve every relative or partial date against this (e.g. "next Friday", "Week 3", "10/14").`,
    "For each assignment, output dueAt as an ISO 8601 date-time in the student's time zone. If only a date is given with no time, use 23:59 local time. If no due date can be determined, omit that assignment entirely.",
    "Set status to \"Not Started\" unless the source clearly marks it submitted or graded. Choose the single closest type. Set confidence between 0 and 1 reflecting how sure you are the item is a real, dated assignment.",
    "If the source contains no assignments, return an empty list.",
  ].join("\n");
}

// Strip a fetched HTML page down to readable text before handing it to the model.
function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60_000);
}

const FETCH_TIMEOUT_MS = 10_000;
const MAX_REDIRECTS = 3;

// Fetches a user-supplied URL with an SSRF guard on every hop (redirects are
// followed manually and re-validated), a request timeout, and a size cap read
// by the caller. `validate` rejects private/reserved hosts (and, for images,
// restricts to this project's Storage).
async function safeFetch(rawUrl: string, validate: (u: string) => URL): Promise<Response> {
  let current = validate(rawUrl).toString();
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    const res = await fetch(current, {
      redirect: "manual",
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      headers: { "User-Agent": "Cairn-Import/1.0" },
    });
    if (res.status >= 300 && res.status < 400) {
      const location = res.headers.get("location");
      if (!location) return res;
      current = validate(new URL(location, current).toString()).toString();
      continue;
    }
    return res;
  }
  throw new Error("too many redirects");
}

async function readCappedBytes(res: Response, maxBytes: number): Promise<Uint8Array> {
  const bytes = new Uint8Array(await res.arrayBuffer());
  if (bytes.byteLength > maxBytes) throw new Error("response too large");
  return bytes;
}

async function buildParts(req: ExtractRequest): Promise<Part[]> {
  const instruction: Part = { text: "Extract the assignments from the following source." };

  if (req.imageBase64) {
    if (!req.mediaType) throw new Error("mediaType is required with imageBase64");
    if (!isAllowedImageMediaType(req.mediaType)) throw new Error("unsupported image type");
    if (decodedBase64Size(req.imageBase64) > MAX_IMAGE_BYTES) throw new Error("image too large");
    return [instruction, { inlineData: { mimeType: req.mediaType, data: req.imageBase64 } }];
  }
  if (req.imageUrl) {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const res = await safeFetch(req.imageUrl, (u) => assertOwnStorageUrl(u, supabaseUrl));
    if (!res.ok) throw new Error(`could not fetch imageUrl (${res.status})`);
    const bytes = await readCappedBytes(res, MAX_IMAGE_BYTES);
    const mimeType = req.mediaType ?? res.headers.get("content-type") ?? "image/png";
    return [instruction, { inlineData: { mimeType, data: encodeBase64(bytes) } }];
  }
  if (req.pageUrl) {
    const res = await safeFetch(req.pageUrl, assertPublicHttpUrl);
    if (!res.ok) throw new Error(`could not fetch pageUrl (${res.status})`);
    const bytes = await readCappedBytes(res, MAX_FETCH_BYTES);
    const text = htmlToText(new TextDecoder().decode(bytes));
    return [{ text: `Class page content:\n\n${text}` }];
  }
  if (req.text) {
    return [{ text: `Source text:\n\n${req.text.slice(0, 60_000)}` }];
  }
  throw new Error("provide one of: imageBase64, imageUrl, pageUrl, text");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  // Resolve the caller so anonymous requests can't reach the model.
  const authHeader = request.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ error: "unauthorized" }, 401);
  }

  // Per-user daily quota, enforced atomically in Postgres so the paid model key
  // can't be burned by runaway use. Fail open on a transient RPC error rather
  // than blocking a legitimate user.
  const dailyLimit = Number(Deno.env.get("EXTRACTION_DAILY_LIMIT") ?? "50");
  const { data: usageCount, error: usageErr } = await supabase.rpc(
    "increment_extraction_usage",
    { daily_limit: dailyLimit },
  );
  if (!usageErr && typeof usageCount === "number" && usageCount < 0) {
    return json({ error: "daily extraction limit reached; try again tomorrow" }, 429);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "GEMINI_API_KEY not configured" }, 500);

  let req: ExtractRequest;
  try {
    req = (await request.json()) as ExtractRequest;
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const now = req.now ?? new Date().toISOString();
  const timeZone = req.timeZone ?? "UTC";

  let parts: Part[];
  try {
    parts = await buildParts(req);
  } catch (err) {
    return json({ error: String((err as Error).message) }, 400);
  }

  try {
    const ai = new GoogleGenAI({ apiKey });
    const response = await ai.models.generateContent({
      model: Deno.env.get("GEMINI_MODEL") ?? DEFAULT_MODEL,
      contents: parts,
      config: {
        systemInstruction: systemPrompt(now, timeZone),
        responseMimeType: "application/json",
        // deno-lint-ignore no-explicit-any
        responseSchema: RESULT_SCHEMA as any,
        temperature: 0,
      },
    });

    const raw = response.text ?? "{\"assignments\":[]}";
    const parsed = JSON.parse(raw) as { assignments?: unknown[] };
    return json({ assignments: parsed.assignments ?? [] });
  } catch (err) {
    return json({ error: `extraction failed: ${String((err as Error).message)}` }, 502);
  }
});
