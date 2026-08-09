import { assertEquals, assertThrows } from "jsr:@std/assert";
import {
  assertOwnStorageUrl,
  assertPublicHttpUrl,
  decodedBase64Size,
  isAllowedImageMediaType,
  isBlockedHost,
} from "./security.ts";

Deno.test("isBlockedHost blocks loopback, private, link-local and metadata hosts", () => {
  const blocked = [
    "localhost",
    "app.localhost",
    "printer.local",
    "svc.internal",
    "metadata.google.internal",
    "127.0.0.1",
    "10.0.0.5",
    "172.16.0.1",
    "172.31.255.255",
    "192.168.1.1",
    "169.254.169.254", // cloud metadata
    "100.64.0.1", // CGNAT
    "0.0.0.0",
    "::1",
    "fc00::1",
    "fe80::1",
    "::ffff:127.0.0.1", // mapped loopback
  ];
  for (const host of blocked) {
    assertEquals(isBlockedHost(host), true, `expected ${host} to be blocked`);
  }
});

Deno.test("isBlockedHost allows normal public hosts", () => {
  for (const host of ["example.com", "canvas.university.edu", "8.8.8.8", "172.15.0.1", "172.32.0.1"]) {
    assertEquals(isBlockedHost(host), false, `expected ${host} to be allowed`);
  }
});

Deno.test("assertPublicHttpUrl rejects non-http schemes and private hosts", () => {
  assertThrows(() => assertPublicHttpUrl("file:///etc/passwd"));
  assertThrows(() => assertPublicHttpUrl("ftp://example.com"));
  assertThrows(() => assertPublicHttpUrl("http://169.254.169.254/latest/meta-data"));
  assertThrows(() => assertPublicHttpUrl("http://localhost:54321"));
  assertThrows(() => assertPublicHttpUrl("not a url"));
  // A valid public URL passes through.
  assertEquals(assertPublicHttpUrl("https://canvas.edu/course/1").hostname, "canvas.edu");
});

Deno.test("assertOwnStorageUrl only accepts this project's Storage URLs", () => {
  const base = "https://proj.supabase.co";
  const ok = `${base}/storage/v1/object/sign/imports/user/file.png?token=abc`;
  assertEquals(assertOwnStorageUrl(ok, base).hostname, "proj.supabase.co");
  assertThrows(() => assertOwnStorageUrl("https://evil.com/storage/v1/object/x", base));
  assertThrows(() => assertOwnStorageUrl(`${base}/rest/v1/assignments`, base));
  assertThrows(() => assertOwnStorageUrl(ok, ""));
});

Deno.test("isAllowedImageMediaType accepts image types only", () => {
  assertEquals(isAllowedImageMediaType("image/png"), true);
  assertEquals(isAllowedImageMediaType("IMAGE/JPEG"), true);
  assertEquals(isAllowedImageMediaType("application/pdf"), false);
  assertEquals(isAllowedImageMediaType("text/html"), false);
});

Deno.test("decodedBase64Size approximates decoded byte length", () => {
  // "aGVsbG8=" decodes to "hello" (5 bytes).
  assertEquals(decodedBase64Size("aGVsbG8="), 5);
  assertEquals(decodedBase64Size(""), 0);
});
