import { supabase } from './supabase';

/** Unwraps a Supabase `{data, error}` result, throwing the error. */
export async function must(q) {
  const { data, error } = await q;
  if (error) throw new Error(error.message);
  return data;
}
export { supabase };
