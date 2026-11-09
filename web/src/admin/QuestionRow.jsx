import { QUESTION_TYPE_LABEL } from '../lib/types';

export default function QuestionRow({ q, locked, canUp, canDown, onEdit, onMove, onToggle }) {
  return (
    <div className={`item${q.is_active ? '' : ' dim'}`}>
      <div style={{ minWidth: 0, flex: 1 }}>
        <div className="title">{q.text}</div>
        <div className="small muted">
          {QUESTION_TYPE_LABEL[q.type]}{q.is_required && ' · required'}{!q.is_active && ' · hidden'}
          {q.options && ` · ${q.options.join(', ')}`}
        </div>
      </div>
      {locked ? <span className="pill off">From category</span> : (
        <div className="actions">
          <button type="button" className="btn sm" aria-label="Move up" disabled={!canUp} onClick={() => onMove(-1)}>↑</button>
          <button type="button" className="btn sm" aria-label="Move down" disabled={!canDown} onClick={() => onMove(1)}>↓</button>
          <button type="button" className="btn sm" onClick={onEdit}>Edit</button>
          <button type="button" className="btn sm" onClick={onToggle}>{q.is_active ? 'Hide' : 'Show'}</button>
        </div>
      )}
    </div>
  );
}
