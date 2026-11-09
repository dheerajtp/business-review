const dateTime = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' });
export const formatDateTime = (iso) => dateTime.format(new Date(iso));

export const googleReviewUrl = (placeId) =>
  `https://search.google.com/local/writereview?placeid=${encodeURIComponent(placeId)}`;

export const feedbackUrl = (slug) => `${window.location.origin}/f/${slug}`;

export const errorMessage = (e) =>
  e instanceof Error ? e.message : typeof e === 'object' && e && 'message' in e ? String((e ).message) : 'Something went wrong';

const rtf = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto', style: 'short' });
export function timeAgo(iso) {
  const mins = Math.round((new Date(iso).getTime() - Date.now()) / 60000);
  if (Math.abs(mins) < 60) return rtf.format(mins, 'minute');
  if (Math.abs(mins) < 1440) return rtf.format(Math.round(mins / 60), 'hour');
  return rtf.format(Math.round(mins / 1440), 'day');
}
