import { useId, useState } from 'react';

const EYE = 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z';

export default function PasswordField({ label, value, onChange, autoComplete }) {
  const id = useId();
  const [shown, setShown] = useState(false);
  return (
    <div className="field">
      <label className="label" htmlFor={id}>{label}</label>
      <span className="pw">
        <input id={id} className="input" type={shown ? 'text' : 'password'} autoComplete={autoComplete} required value={value} onChange={onChange} />
        <button type="button" className="pw-toggle" aria-label={shown ? 'Hide password' : 'Show password'} aria-pressed={shown} onClick={() => setShown(!shown)}>
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d={EYE} />
            <circle cx="12" cy="12" r="3" />
            {shown && <path d="M4 4l16 16" />}
          </svg>
        </button>
      </span>
    </div>
  );
}
