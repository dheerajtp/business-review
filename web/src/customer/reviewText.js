// Draft review text for the comment box (decision C8). Pure: the customer edits it before copying.
const lower = (l) => (/[A-Z]/.test(l.slice(1)) ? l : l.toLowerCase());

function joinList(items) {
  if (items.length <= 1) return items.join('');
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
}

export function composeReview({ company, rating, labels }) {
  const list = joinList((labels ?? []).map(lower));
  if (rating >= 4) {
    return list
      ? `Great experience at ${company}! I especially liked the ${list}.`
      : `Great experience at ${company}!`;
  }
  return list
    ? `My visit to ${company} could have been better, mainly the ${list}.`
    : `My visit to ${company} could have been better.`;
}
