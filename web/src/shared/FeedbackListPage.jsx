import { useCallback, useEffect, useState } from 'react';
import { useNewFeedback } from '../notify/NewFeedbackContext';
import StatsStrip from './StatsStrip';
import SubmissionCard from './SubmissionCard';
import { useAuth } from '../auth/AuthContext';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { errorMessage } from '../lib/format';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

const PAGE = 20;

/** Shared by both roles. What each sees is decided by RLS, not by this code. */
export default function FeedbackListPage() {
  const isSuper = useAuth().profile?.role === 'super_admin';
  const meta = useAsync(async () => {
    const [companies, branches, stats] = await Promise.all([
      must(supabase.from('companies').select('id,name,category_id,is_active').order('name')) ,
      must(supabase.from('branches').select('id,company_id,name,slug,google_place_id,is_active').order('name')) ,
      must(supabase.from('branch_stats').select('*')) ,
    ]);
    return { companies, branches, stats };
  }, []);

  const [companyId, setCompanyId] = useState('');
  const [branchId, setBranchId] = useState('');
  const [rating, setRating] = useState('all');
  const [range, setRange] = useState('all');

  // "New" markers use the last-seen time from when this page was opened, so they stay visible during the visit.
  const { ready, seenAt, newCount, markSeen } = useNewFeedback();
  const [since, setSince] = useState(null);
  const [armed, setArmed] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  useEffect(() => { if (ready) setSince((prev) => prev ?? seenAt); }, [ready, seenAt]);
  useEffect(() => {
    if (!ready) return undefined;
    const t = setTimeout(() => { markSeen().then(() => setArmed(true)); }, 3000);
    return () => clearTimeout(t);
  }, [ready, markSeen]);

  const [items, setItems] = useState([]);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchPage = useCallback(async (offset) => {
    let q = supabase.from('feedback_submissions')
      .select('id,branch_id,company_id,rating,answers,comment,contact,clicked_google,created_at')
      .order('created_at', { ascending: false }).range(offset, offset + PAGE - 1);
    if (branchId) q = q.eq('branch_id', branchId); else if (companyId) q = q.eq('company_id', companyId);
    if (rating === 'below4') q = q.lt('rating', 4);
    if (rating === 'low') q = q.lte('rating', 2);
    if (rating === 'high') q = q.gte('rating', 4);
    if (range !== 'all') q = q.gte('created_at', new Date(Date.now() - Number(range) * 86_400_000).toISOString());
    return (await must(q)) ;
  }, [companyId, branchId, rating, range]);

  useEffect(() => {
    let live = true;
    setLoading(true);
    fetchPage(0).then(
      (rows) => { if (live) { setItems(rows); setHasMore(rows.length === PAGE); setError(null); setLoading(false); } },
      (e) => { if (live) { setError(errorMessage(e)); setLoading(false); } },
    );
    return () => { live = false; };
  }, [fetchPage, refreshKey]);

  async function showNew() {
    setRefreshKey((k) => k + 1);
    meta.reload();
    await markSeen();
  }

  async function more() {
    setLoading(true);
    try {
      const rows = await fetchPage(items.length);
      setItems((prev) => [...prev, ...rows]);
      setHasMore(rows.length === PAGE);
    } catch (e) { setError(errorMessage(e)); }
    setLoading(false);
  }

  if (meta.loading && !meta.data) return <ListSkeleton />;
  if (meta.error || !meta.data) return <ErrorState message={meta.error ?? 'Could not load'} onRetry={meta.reload} />;
  const { companies, branches, stats } = meta.data;
  const visibleBranches = branches.filter((b) => !companyId || b.company_id === companyId);
  const scoped = stats.filter((s) => (!branchId || s.branch_id === branchId) && (!companyId || s.company_id === companyId));
  const branchName = (id) => branches.find((b) => b.id === id)?.name ?? 'Branch';
  const companyName = (id) => companies.find((c) => c.id === id)?.name;

  return (
    <>
      <PageHead title="Feedback" subtitle={isSuper ? 'Everything customers have submitted.' : 'What customers told you. Ratings below 4 stars are flagged.'} />
      {armed && newCount > 0 && (
        <div className="new-bar" role="status">
          <span>{newCount >= 100 ? '99+' : newCount} new {newCount === 1 ? 'response' : 'responses'} since you opened this page</span>
          <button type="button" className="btn sm primary" onClick={() => void showNew()}>Show</button>
        </div>
      )}
      <StatsStrip stats={scoped} />

      <div className="filters">
        {isSuper && (
          <label className="field"><span className="label">Company</span>
            <select className="select" value={companyId} onChange={(e) => { setCompanyId(e.target.value); setBranchId(''); }}>
              <option value="">All companies</option>
              {companies.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </label>
        )}
        <label className="field"><span className="label">Branch</span>
          <select className="select" value={branchId} onChange={(e) => setBranchId(e.target.value)}>
            <option value="">All branches</option>
            {visibleBranches.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
          </select>
        </label>
        <label className="field"><span className="label">Rating</span>
          <select className="select" value={rating} onChange={(e) => setRating(e.target.value )}>
            <option value="all">All ratings</option>
            <option value="below4">Below 4 stars (needs attention)</option>
            <option value="low">1–2 stars (urgent)</option>
            <option value="high">4–5 stars</option>
          </select>
        </label>
        <label className="field"><span className="label">Period</span>
          <select className="select" value={range} onChange={(e) => setRange(e.target.value )}>
            <option value="all">All time</option>
            <option value="7">Last 7 days</option>
            <option value="30">Last 30 days</option>
          </select>
        </label>
      </div>

      {error && <ErrorState message={error} />}
      {loading && items.length === 0 && <ListSkeleton />}
      {!loading && !error && items.length === 0 && <EmptyState title="No feedback matches" hint="Try widening the filters." />}
      <div className="list">
        {items.map((s) => <SubmissionCard key={s.id} s={s} branchName={branchName(s.branch_id)} companyName={isSuper ? companyName(s.company_id) : undefined} isNew={since !== null && new Date(s.created_at) > new Date(since)} />)}
      </div>
      {hasMore && <div style={{ textAlign: 'center', marginTop: 16 }}><button type="button" className="btn" disabled={loading} onClick={() => void more()}>{loading ? 'Loading…' : 'Load more'}</button></div>}
    </>
  );
}
