// Draft review text for the comment box (decision K8). Pure: the customer edits it before copying.
function joinList(items) {
  if (items.length <= 1) return items.join('');
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
}

export function composeReview({ company, rating, labels }) {
  const list = joinList(labels ?? []);
  if (rating >= 4) {
    return list
      ? `Great experience at ${company}! Recommended for ${list}.`
      : `Great experience at ${company}!`;
  }
  return list
    ? `My visit to ${company} could have been better, especially regarding ${list}.`
    : `My visit to ${company} could have been better.`;
}
