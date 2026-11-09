import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import AdminLoginForm from './AdminLoginForm';
import BranchForm from './BranchForm';
import BranchQr from './BranchQr';
import LoginList from './LoginList';
import ConfirmDialog from '../ui/ConfirmDialog';
import EmptyState from '../ui/EmptyState';
import ErrorState from '../ui/ErrorState';
import ListSkeleton from '../ui/ListSkeleton';
import PageHead from '../ui/PageHead';
import { must, supabase } from '../lib/db';
import { useAsync } from '../lib/useAsync';

export default function CompanyDetailPage() {
  const { id = '' } = useParams();
  const { data, error, loading, reload } = useAsync(async () => {
    const [company, branches, logins] = await Promise.all([
      must(supabase.from('companies').select('id,name,category_id,is_active').eq('id', id).single()) ,
      must(supabase.from('branches').select('id,company_id,name,slug,google_place_id,is_active').eq('company_id', id).order('name')),
      // The logins list must not take the whole page down if it fails (e.g. a migration not applied yet).
      must(supabase.rpc('list_business_admins', { p_company_id: id })).then((rows) => ({ rows }), (e) => ({ error: e.message })),
    ]);
    return { company, branches, logins };
  }, [id]);
  const [editing, setEditing] = useState(null);
  const [qr, setQr] = useState(null);
  const [toggling, setToggling] = useState(null);
  const [login, setLogin] = useState(false);

  if (loading && !data) return <ListSkeleton />;
  if (error || !data) return <ErrorState message={error ?? 'Company not found'} onRetry={reload} />;
  const { company, branches, logins } = data;

  return (
    <>
      <p className="small" style={{ marginBottom: 8 }}><Link to="/admin/companies">← Companies</Link></p>
      <PageHead title={company.name} subtitle="Branches each get their own NFC tag, QR code and Google listing.">
        <div className="row">
          <button type="button" className="btn" onClick={() => setLogin(true)}>Add business login</button>
          <button type="button" className="btn primary" onClick={() => setEditing('new')}>New branch</button>
        </div>
      </PageHead>

      {branches.length === 0 && <EmptyState title="No branches yet" hint="Add a branch to get its NFC link and QR code." />}
      <div className="list">
        {branches.map((b) => (
          <div key={b.id} className={`item${b.is_active ? '' : ' dim'}`}>
            <div>
              <div className="title">{b.name} {!b.is_active && <span className="pill off">Archived</span>}</div>
              <div className="muted small mono">/f/{b.slug}</div>
            </div>
            <div className="actions">
              <button type="button" className="btn sm primary" onClick={() => setQr(b)}>NFC &amp; QR</button>
              <button type="button" className="btn sm" onClick={() => setEditing(b)}>Edit</button>
              <button type="button" className="btn sm" onClick={() => setToggling(b)}>{b.is_active ? 'Archive' : 'Restore'}</button>
            </div>
          </div>
        ))}
      </div>

      <h2 style={{ margin: '32px 0 12px' }}>Business logins</h2>
      <LoginList logins={logins.rows} error={logins.error} onAdd={() => setLogin(true)} />

      {editing && <BranchForm companyId={company.id} branch={editing === 'new' ? null : editing} onSaved={reload} onClose={() => setEditing(null)} />}
      {qr && <BranchQr branch={qr} onClose={() => setQr(null)} />}
      {login && <AdminLoginForm companyId={company.id} companyName={company.name} onCreated={reload} onClose={() => setLogin(false)} />}
      {toggling && (
        <ConfirmDialog
          title={toggling.is_active ? `Archive ${toggling.name}?` : `Restore ${toggling.name}?`}
          message={toggling.is_active
            ? 'The NFC tag and QR code for this branch stop working until it is restored. Existing feedback is kept.'
            : 'The NFC tag and QR code for this branch will work again.'}
          confirmLabel={toggling.is_active ? 'Archive' : 'Restore'}
          onClose={() => setToggling(null)}
          onConfirm={async () => { await must(supabase.from('branches').update({ is_active: !toggling.is_active }).eq('id', toggling.id).select()); reload(); }}
        />
      )}
    </>
  );
}
