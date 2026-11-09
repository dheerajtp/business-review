
export default function QuestionField({ q, value, onChange, invalid }) {
  const name = `q-${q.id}`;
  return (
    <fieldset className="qblock" aria-invalid={invalid || undefined}>
      <legend>
        {q.text} {q.is_required ? <span className="req" aria-label="required">*</span> : <span className="muted small">(optional)</span>}
      </legend>

      {q.type === 'scale' && (
        <>
          <div className="scale">
            {[1, 2, 3, 4, 5].map((n) => (
              <label key={n} className="opt">
                <input type="radio" name={name} checked={value === n} onChange={() => onChange(n)} />
                <span>{n}</span>
              </label>
            ))}
          </div>
          <div className="scale-ends" aria-hidden="true"><span>Low</span><span>High</span></div>
        </>
      )}

      {q.type === 'single' && (
        <div className="opts">
          {q.options?.map((o) => (
            <label key={o} className="opt">
              <input type="radio" name={name} checked={value === o} onChange={() => onChange(o)} />
              <span>{o}</span>
            </label>
          ))}
        </div>
      )}

      {q.type === 'multi' && (
        <div className="opts">
          {q.options?.map((o) => {
            const picked = Array.isArray(value) ? value : [];
            return (
              <label key={o} className="opt">
                <input type="checkbox" checked={picked.includes(o)} onChange={(e) => onChange(e.target.checked ? [...picked, o] : picked.filter((x) => x !== o))} />
                <span>{o}</span>
              </label>
            );
          })}
        </div>
      )}

      {q.type === 'text' && (
        <textarea className="textarea" maxLength={1000} aria-label={q.text} value={typeof value === 'string' ? value : ''} onChange={(e) => onChange(e.target.value)} />
      )}

      {invalid && <p className="small" role="alert" style={{ color: 'var(--danger)', marginTop: 8 }}>Please answer this one.</p>}
    </fieldset>
  );
}
