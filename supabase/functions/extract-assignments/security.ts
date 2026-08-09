// Pure, dependency-free validators for the extract-assignments Edge Function.
// Kept separate from index.ts so they can be unit-tested with `deno test` without
// network, env, or the Gemini/Supabase SDKs.

// Decoded image byte cap. Base64 inflates by ~4/3, so this bounds what we forward
// to the model regardless of the request encoding.
export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;

// Cap on a fetched page/image body, guarding against oversized responses.
export const MAX_FETCH_BYTES = 8 * 1024 * 1024;

export const ALLOWED_IMAGE_MEDIA_TYPES = [
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/heic",
  "image/heif",
];

export function isAllowedImageMediaType(mediaType: string): boolean {
  return ALLOWED_IMAGE_MEDIA_TYPES.includes(mediaType.trim().toLowerCase());
}

/// Approximate decoded byte length of a base64 string (no data: prefix).
export function decodedBase64Size(base64: string): number {
  const cleaned = base64.trim();
  if (cleaned.length === 0) return 0;
  const padding = cleaned.endsWith("==") ? 2 : cleaned.endsWith("=") ? 1 : 0;
  return Math.floor((cleaned.length * 3) / 4) - padding;
}

/// Validates a user-supplied URL is a public http(s) URL, rejecting the obvious
/// SSRF targets (localhost, private/reserved IP ranges, cloud metadata hosts).
/// Returns the parsed URL or throws. Note: DNS names that resolve to private IPs
/// are not caught here — call sites may add a resolve-time check where supported.
export function assertPublicHttpUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error("invalid URL");
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("only http(s) URLs are allowed");
  }
  if (isBlockedHost(url.hostname)) {
    throw new Error("URL host is not allowed");
  }
  return url;
}

/// For imageUrl: must be a Storage URL belonging to this project, closing the
/// SSRF surface entirely for the image-by-URL path.
export function assertOwnStorageUrl(raw: string, supabaseUrl: string): URL {
  const url = assertPublicHttpUrl(raw);
  const base = supabaseUrl.replace(/\/+$/, "");
  if (base.length === 0 || !raw.startsWith(`${base}/storage/v1/object/`)) {
    throw new Error("imageUrl must be a Supabase Storage URL for this project");
  }
  return url;
}

export function isBlockedHost(hostname: string): boolean {
  const host = hostname.trim().toLowerCase().replace(/^\[|\]$/g, "");
  if (host.length === 0) return true;
  if (
    host === "localhost" ||
    host.endsWith(".localhost") ||
    host.endsWith(".local") ||
    host.endsWith(".internal") ||
    host === "metadata" ||
    host === "metadata.google.internal"
  ) {
    return true;
  }
  if (isIPv4(host)) return isPrivateIPv4(host);
  if (host.includes(":")) return isPrivateIPv6(host);
  return false;
}

function isIPv4(host: string): boolean {
  const match = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!match) return false;
  return match.slice(1).every((octet) => Number(octet) <= 255);
}

function isPrivateIPv4(host: string): boolean {
  const [a, b] = host.split(".").map(Number);
  if (a === 0 || a === 10 || a === 127) return true; // this-network, private, loopback
  if (a === 169 && b === 254) return true; // link-local (incl. 169.254.169.254 metadata)
  if (a === 172 && b >= 16 && b <= 31) return true; // private
  if (a === 192 && b === 168) return true; // private
  if (a === 100 && b >= 64 && b <= 127) return true; // CGNAT 100.64.0.0/10
  if (a === 192 && b === 0) return true; // 192.0.0.0/24 + 192.0.2.0/24 (test)
  if (a >= 224) return true; // multicast + reserved + broadcast
  return false;
}

function isPrivateIPv6(host: string): boolean {
  if (host === "::1" || host === "::") return true; // loopback, unspecified
  if (/^f[cd]/.test(host)) return true; // fc00::/7 unique-local
  if (/^fe[89ab]/.test(host)) return true; // fe80::/10 link-local
  if (host.startsWith("::ffff:")) {
    const mapped = host.slice("::ffff:".length);
    if (isIPv4(mapped)) return isPrivateIPv4(mapped);
    return true;
  }
  return false;
}
