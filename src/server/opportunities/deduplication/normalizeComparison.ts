// Deterministic text/URL normalization for comparison — conservative.

export function normalizeText(value: string | null | undefined): string {
  if (!value) return "";
  let s = value.trim().toLowerCase();
  // Normalize Unicode punctuation to ASCII equivalents
  s = s
    .replace(/[“”„‟]/g, '"')
    .replace(/[‘’‚‛]/g, "'")
    .replace(/[–—]/g, "-")
    .replace(/…/g, "...");
  // Normalize & vs and (conservative: replace " & " and " &amp; "?)
  s = s.replace(/\s*&\s*/g, " and ");
  s = s.replace(/\s+/g, " "); // collapse whitespace
  // Remove insignificant punctuation but keep alphanumeric and spaces and hyphens
  // Keep years/numbers: do not remove digits
  // Remove trailing/leading punctuation
  s = s.replace(/[.,;:!?()[\]{}"'`]/g, " ");
  s = s.replace(/\s+/g, " ").trim();
  // Collapse again
  return s;
}

export function normalizeOrganization(value: string | null | undefined): string {
  return normalizeText(value);
}

export function normalizeUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    // Lowercase hostname
    url.hostname = url.hostname.toLowerCase();
    // Remove fragment (hash) — navigation fragments not meaningful for identity
    url.hash = "";
    // Remove trailing slash for pathname (but keep root "/")
    if (url.pathname.length > 1 && url.pathname.endsWith("/")) {
      url.pathname = url.pathname.slice(0, -1);
    }
    // Remove obvious tracking query params (utm_*, fbclid, gclid, etc.) but preserve meaningful params
    const params = new URLSearchParams(url.search);
    const toDelete: string[] = [];
    for (const key of params.keys()) {
      const lower = key.toLowerCase();
      if (
        lower.startsWith("utm_") ||
        lower === "fbclid" ||
        lower === "gclid" ||
        lower === "mc_eid" ||
        lower === "mc_cid" ||
        lower === "_hsenc" ||
        lower === "_hsmi"
      ) {
        toDelete.push(key);
      }
    }
    for (const k of toDelete) params.delete(k);
    // Rebuild search (preserve order of remaining)
    url.search = params.toString() ? `?${params.toString()}` : "";
    // Lowercase pathname? No — preserve case for path (some servers case-sensitive) but hostname already lowercased
    // Do not blindly strip all query params
    return url.toString();
  } catch {
    // Fallback: lowercase and trim, remove trailing slash
    let fallback = trimmed.toLowerCase().replace(/\/$/, "");
    return fallback || null;
  }
}

export function normalizeDeadline(value: string | null | undefined): string | null {
  if (!value) return null;
  const t = value.trim();
  if (!t || t.toLowerCase() === "not specified") return null;
  // Expect YYYY-MM-DD, return as is if matches
  if (/^\d{4}-\d{2}-\d{2}$/.test(t)) return t;
  // Try ISO parse and normalize to YYYY-MM-DD
  const d = new Date(t);
  if (!isNaN(d.getTime()) && /\d{4}/.test(t)) {
    const y = d.getUTCFullYear();
    if (y >= 2000 && y <= 2100) {
      const m = String(d.getUTCMonth() + 1).padStart(2, "0");
      const day = String(d.getUTCDate()).padStart(2, "0");
      return `${y}-${m}-${day}`;
    }
  }
  return t; // preserve as normalized text fallback
}
