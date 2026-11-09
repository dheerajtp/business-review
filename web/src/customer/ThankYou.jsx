import { useState } from 'react';
import { googleReviewUrl } from '../lib/format';
import { supabase } from '../lib/supabase';

export default function ThankYou({ form, draft, submissionId }) {
  const [copied, setCopied] = useState(false);
  const low = draft.rating < 4;
  const comment = draft.comment.trim();

  async function copy() {
    try {
      await navigator.clipboard.writeText(comment);
      setCopied(true);
    } catch {
      // Clipboard can be blocked (older browsers, insecure origin); the text is still on screen.
      setCopied(false);
    }
  }

  return (
    <main className="thanks">
      <h1>Thank you!</h1>
      <p className="muted" style={{ marginTop: 8 }}>Your feedback for {form.branch_name} has been received.</p>

      <div className={`choices${low ? ' two' : ''}`}>
        <section className="choice" aria-labelledby="g-h">
          <h2 id="g-h">Share it on Google</h2>
          <p className="muted">A public review helps other people find {form.company_name}. It takes about a minute.</p>
          {comment && (
            <>
              <p className="small" style={{ background: 'var(--bg)', padding: 12, borderRadius: 8, whiteSpace: 'pre-wrap' }}>{comment}</p>
              <button type="button" className="btn" onClick={() => void copy()}>{copied ? 'Copied ✓' : 'Copy my comment'}</button>
            </>
          )}
          <a
            className="btn primary"
            href={googleReviewUrl(form.google_place_id)}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => void supabase.rpc('mark_google_click', { p_id: submissionId })}
          >
            Write a Google review
          </a>
        </section>

        {low && (
          <section className="choice" aria-labelledby="m-h">
            <h2 id="m-h">The manager has your feedback</h2>
            <p className="muted">
              We're sorry this visit fell short. Your feedback has been sent privately to the team at {form.branch_name} so they can look into it.
              {draft.contact.trim() && ' They may use the contact details you shared to follow up.'}
            </p>
          </section>
        )}
      </div>
      <span className="sr-only" role="status">{copied ? 'Comment copied to clipboard' : ''}</span>
    </main>
  );
}
