import { useState } from 'react';
import FeedbackFormView from '../customer/FeedbackFormView';
import { EMPTY_DRAFT } from '../lib/types';

/** Phone-framed, interactive copy of the customer form. Nothing is submitted. */
export default function FormPreview({ form }) {
  const [draft, setDraft] = useState(EMPTY_DRAFT);
  return (
    <div>
      <p className="small muted" style={{ textAlign: 'center', marginBottom: 8 }}>Live preview. Tap a star to see the questions.</p>
      <div className="phone" aria-label="Customer form preview">
        <div className="phone-in"><FeedbackFormView preview form={form} draft={draft} onDraft={setDraft} /></div>
      </div>
    </div>
  );
}
