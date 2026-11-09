import { useState } from 'react';
import Modal from '../ui/Modal';
import Field from '../ui/Field';
import { must, supabase } from '../lib/db';
import { errorMessage } from '../lib/format';
import { QUESTION_TYPE_LABEL } from '../lib/types';

export default function QuestionForm({ categoryId, companyId, question, initialText, nextOrder, onSaved, onClose }) {
  const [text, setText] = useState(question?.text ?? initialText ?? '');
  const [type, setType] = useState(question?.type ?? 'scale');
  const [options, setOptions] = useState((question?.options ?? []).join('\n'));
  const [required, setRequired] = useState(question?.is_required ?? false);
  const [active, setActive] = useState(question?.is_active ?? true);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const needsOptions = type === 'single' || type === 'multi';

  async function save(e) {
    e.preventDefault();
    const opts = [...new Set(options.split('\n').map((o) => o.trim()).filter(Boolean))];
    if (needsOptions && (opts.length < 2 || opts.length > 12)) return setError('Add between 2 and 12 options, one per line.');
    setBusy(true);
    setError(null);
    const row = { text: text.trim(), type, options: needsOptions ? opts : null, is_required: required, is_active: active };
    try {
      await must(question
        ? supabase.from('questions').update(row).eq('id', question.id).select()
        : supabase.from('questions').insert({ ...row, category_id: categoryId, company_id: companyId, sort_order: nextOrder }).select());
      await onSaved();
      onClose();
    } catch (err) { setError(errorMessage(err)); setBusy(false); }
  }

  return (
    <Modal title={question ? 'Edit question' : 'New question'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <Field label="Question"><input className="input" required maxLength={300} value={text} onChange={(e) => setText(e.target.value)} /></Field>
        <Field label="Answer format">
          <select className="select" value={type} onChange={(e) => setType(e.target.value )}>
            {(Object.keys(QUESTION_TYPE_LABEL) ).map((t) => <option key={t} value={t}>{QUESTION_TYPE_LABEL[t]}</option>)}
          </select>
        </Field>
        {needsOptions && (
          <Field label="Options" hint="One per line, 2 to 12.">
            <textarea className="textarea" value={options} onChange={(e) => setOptions(e.target.value)} />
          </Field>
        )}
        <label className="check"><input type="checkbox" checked={required} onChange={(e) => setRequired(e.target.checked)} /> Customers must answer</label>
        <label className="check"><input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> Shown to customers</label>
        {error && <p className="alert" role="alert">{error}</p>}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
        </div>
      </form>
    </Modal>
  );
}
