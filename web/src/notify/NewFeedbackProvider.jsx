import { useCallback, useEffect, useMemo, useState } from 'react';
import { NewFeedbackContext } from './NewFeedbackContext';
import { useAuth } from '../auth/AuthContext';
import { supabase } from '../lib/supabase';

const POLL_MS = 20000;
const CAP = 100;

/** Tracks "responses since you last looked": the sidebar badge, the tab title, and the in-page "new" prompt. */
export default function NewFeedbackProvider({ children }) {
  const { userId, profile } = useAuth();
  const isSuper = profile?.role === 'super_admin';
  const [seenAt, setSeenAt] = useState(null);
  const [fresh, setFresh] = useState({ count: 0, low: 0, items: [] });
  const [pendingRequests, setPendingRequests] = useState(0);

  useEffect(() => {
    let live = true;
    supabase.from('profiles').select('last_seen_at').eq('user_id', userId).maybeSingle()
      .then(({ data }) => { if (live && data) setSeenAt(data.last_seen_at); });
    return () => { live = false; };
  }, [userId]);

  // Check for new responses now, every 20s while the tab is visible, and when the tab becomes visible again.
  useEffect(() => {
    if (!seenAt) return;
    let live = true;
    const check = async () => {
      if (document.hidden) return;
      const { data } = await supabase.from('feedback_submissions').select('id,rating,comment,created_at,branches(name)')
        .gt('created_at', seenAt).order('created_at', { ascending: false }).limit(CAP);
      if (live && data) setFresh({ count: data.length, low: data.filter((r) => r.rating < 4).length, items: data.slice(0, 5) });
      if (isSuper) {
        const { count } = await supabase.from('question_requests').select('id', { count: 'exact', head: true }).eq('status', 'pending');
        if (live && count !== null) setPendingRequests(count);
      }
    };
    check();
    const timer = setInterval(check, POLL_MS);
    document.addEventListener('visibilitychange', check);
    return () => { live = false; clearInterval(timer); document.removeEventListener('visibilitychange', check); };
  }, [seenAt, isSuper]);

  useEffect(() => {
    document.title = fresh.count ? `(${fresh.count >= CAP ? `${CAP - 1}+` : fresh.count}) Feedback` : 'Feedback';
    return () => { document.title = 'Feedback'; };
  }, [fresh.count]);

  const markSeen = useCallback(async () => {
    const { data } = await supabase.rpc('mark_feedback_seen');
    if (data) { setSeenAt(data); setFresh({ count: 0, low: 0, items: [] }); }
  }, []);

  const value = useMemo(
    () => ({ ready: seenAt !== null, seenAt, newCount: fresh.count, newLow: fresh.low, items: fresh.items, pendingRequests, markSeen }),
    [seenAt, fresh, pendingRequests, markSeen],
  );
  return <NewFeedbackContext.Provider value={value}>{children}</NewFeedbackContext.Provider>;
}
