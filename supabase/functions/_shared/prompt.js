// Prompt for AI review drafts (plan 06, A7). The customer controls only the rating
// and the keyword ids; everything else comes from the database.
const SYSTEM =
  "You write short customer reviews for a business. Write 2 to 4 sentences in the first person, " +
  "natural and plain text (no emojis, hashtags, quotes or markdown). Use only the business name, " +
  "the rating and the keywords provided; do not invent details, names, prices, dates or staff. " +
  "Include each keyword naturally, keeping its wording where it reads well. Match the tone to the " +
  "rating: 4 to 5 warm and positive, 3 mixed, 1 to 2 honest and constructive, never insulting. " +
  "At most 500 characters.";

export function buildPrompt({ company_name, branch_name, category_name, subcategory_name, rating, labels }) {
  const keywords = Array.isArray(labels) && labels.length > 0 ? labels.join(", ") : "none";
  const user =
    `Business: ${company_name} (${branch_name}); Type: ${category_name} / ${subcategory_name}; ` +
    `Rating: ${rating} out of 5; Keywords: ${keywords}`;
  return { system: SYSTEM, user };
}

// Trim, strip wrapping quotes (of the whole text and of each line), collapse whitespace,
// cut to 600 characters. '' means failure.
const WRAP_QUOTES = /^["'“”‘’]+|["'“”‘’]+$/g;
const unwrap = (s) => s.trim().replace(WRAP_QUOTES, "").trim();

export function sanitizeReview(text) {
  if (typeof text !== "string") return "";
  const s = unwrap(text).split(/\r?\n/).map(unwrap).join(" ").replace(/\s+/g, " ").trim();
  return s.slice(0, 600).trim();
}
