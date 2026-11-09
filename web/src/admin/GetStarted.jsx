import { Link } from 'react-router-dom';

// Steps in setup order. `done` comes from simple counts of what already exists.
const STEPS = [
  ['categories', 'Create a category', 'A type of business, such as Café or Boutique.', '/admin/categories'],
  ['questions', 'Add the questions', 'What customers are asked for each category.', '/admin/questions'],
  ['companies', 'Add a company', 'One for each business you serve.', '/admin/companies'],
  ['branches', 'Add its branches', 'Each branch gets its own NFC link and QR code.', '/admin/companies'],
  ['logins', 'Create a business login', 'So the company can see its own feedback.', '/admin/companies'],
];

export default function GetStarted({ counts }) {
  const doneCount = STEPS.filter(([key]) => counts[key] > 0).length;
  const firstOpen = STEPS.findIndex(([key]) => counts[key] === 0);
  return (
    <section className="card started" aria-labelledby="gs-h">
      <header>
        <h2 id="gs-h">Get started</h2>
        <p className="muted">No feedback has come in yet. Set things up in this order, then write an NFC card or print a QR code for each branch.</p>
        <div className="meter" role="meter" aria-valuemin={0} aria-valuemax={STEPS.length} aria-valuenow={doneCount} aria-label="Setup progress">
          <span style={{ width: `${(doneCount / STEPS.length) * 100}%` }} />
        </div>
        <p className="small muted">{doneCount} of {STEPS.length} steps done</p>
      </header>
      <ol className="stepper">
        {STEPS.map(([key, title, hint, to], i) => {
          const done = counts[key] > 0;
          return (
            <li key={key} className={done ? 'done' : i === firstOpen ? 'next' : undefined}>
              <span className="step-mark" aria-hidden="true">{done ? '✓' : i + 1}</span>
              <div>
                <p className="step-title">{title} {done && <span className="sr-only">(done)</span>}</p>
                <p className="small muted">{hint}</p>
              </div>
              {!done && <Link className={`btn sm${i === firstOpen ? ' primary' : ''}`} to={to}>{i === firstOpen ? 'Start' : 'Open'}</Link>}
            </li>
          );
        })}
      </ol>
    </section>
  );
}
