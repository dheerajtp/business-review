// Pure helpers, no app imports: importable by node for checks.

/** 'android-web-nfc' | 'android-other' | 'ios' | 'desktop' */
export function nfcEnvironment(env = globalThis) {
  const nav = env.navigator;
  if (!nav) return 'desktop';
  const ua = nav.userAgent || '';
  if (/Android/i.test(ua)) {
    return 'NDEFReader' in env && env.isSecureContext ? 'android-web-nfc' : 'android-other';
  }
  if (/iPhone|iPad|iPod/i.test(ua) || (nav.platform === 'MacIntel' && nav.maxTouchPoints > 1)) return 'ios';
  return 'desktop';
}

export const isLocalHost = (env = globalThis) =>
  /^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(env.location?.hostname ?? '');

export const handoffUrl = (companyId, branchId, env = globalThis) =>
  `${env.location.origin}/admin/companies/${companyId}?nfc=${branchId}`;
