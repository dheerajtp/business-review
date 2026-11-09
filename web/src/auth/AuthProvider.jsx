import { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '../lib/supabase';
import { AuthContext } from './AuthContext';

export default function AuthProvider({ children }) {
  const [userId, setUserId] = useState(undefined); // undefined = still checking
  const [email, setEmail] = useState(null);
  const [profile, setProfile] = useState(undefined);

  useEffect(() => {
    const apply = (session) => { setUserId(session?.user.id ?? null); setEmail(session?.user.email ?? null); };
    supabase.auth.getSession().then(({ data }) => apply(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, session) => apply(session));
    return () => data.subscription.unsubscribe();
  }, []);

  // Load the role outside the auth callback (calling Supabase inside it can deadlock).
  useEffect(() => {
    if (userId === undefined) return;
    if (userId === null) { setProfile(null); return; }
    let live = true;
    setProfile(undefined);
    supabase.from('profiles').select('role, company_id').eq('user_id', userId).maybeSingle()
      .then(({ data }) => { if (live) setProfile((data ) ?? null); });
    return () => { live = false; };
  }, [userId]);

  const signIn = useCallback(async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return error ? 'Wrong email or password.' : null;
  }, []);
  const signOut = useCallback(async () => { await supabase.auth.signOut(); }, []);

  const value = useMemo(() => {
    const status =
      userId === undefined || (userId && profile === undefined) ? 'loading'
      : userId === null ? 'signed_out'
      : profile ? 'signed_in' : 'no_profile';
    return { status, userId: userId ?? null, email, profile: profile ?? null, signIn, signOut };
  }, [userId, email, profile, signIn, signOut]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
