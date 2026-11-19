// Base URL guard for custom AI endpoints. Mirrors public.ai_valid_base_url in SQL:
// https only, <= 300 chars, no credentials/query/fragment, host not localhost,
// not an IPv4/IPv6 literal, not ending in .local or .internal.
const SHAPE = /^https:\/\/([^/:@?#]+)(:[0-9]+)?(\/[^?#]*)?$/;

export function isValidBaseUrl(url) {
  if (typeof url !== "string" || url.length > 300 || /\s/.test(url)) return false;
  const m = SHAPE.exec(url);
  if (!m) return false;
  const host = m[1].toLowerCase().replace(/\.+$/, "");
  if (host === "localhost") return false;
  if (/^[0-9.]+$/.test(host)) return false;
  if (host.includes(":") || host.includes("[")) return false;
  if (/\.(local|internal)$/.test(host)) return false;
  return true;
}

export function normalizeBaseUrl(url) {
  return url.replace(/\/+$/, "");
}
