import { errorMessage } from '../lib/format';

/** Friendly text for a failed taxonomy save; `must` keeps only the message, so match unique-violation (23505) text. */
export const taxonomyError = (err) =>
  /duplicate key|unique constraint/i.test(errorMessage(err)) ? 'That name already exists here.' : errorMessage(err);
