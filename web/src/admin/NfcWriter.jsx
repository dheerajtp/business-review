import { useEffect, useRef, useState } from 'react';
import QRCode from 'qrcode';
import { isLocalHost, nfcEnvironment } from '../lib/nfcSupport';

const ERRORS = {
  NotAllowedError: 'NFC permission was denied. Allow NFC for this site in the browser settings and try again.',
  NotSupportedError: 'NFC is switched off or not available on this phone. Turn it on in the phone settings.',
  NetworkError: 'The card moved away or could not be written. Hold it steady against the back of the phone and try again.',
};

const STEPS = {
  ios: [
    'Tap "Send link" (or copy the link above) so the feedback link is on your iPhone.',
    'Install the free "NFC Tools" app from the App Store.',
    'In NFC Tools choose Write, then Add a record, then URL/URI, paste the link and tap Write. Hold the card to the top edge of the iPhone.',
    'Needs an iPhone 7 or newer.',
  ],
  'android-other': [
    'Tap "Copy page address", then open it in Chrome on this phone and use the Write button there.',
    'Or install the free "NFC Tools" app, add a URL/URI record with the link and write it to the card.',
  ],
  desktop: [
    'Scan the QR code below with an Android phone, then use the Write button on that phone.',
    'Or connect a USB NFC reader (for example an ACR122U-class reader), open the free NFC Tools desktop app and write the link as a URL record.',
  ],
};

export default function NfcWriter({ url, branchName = '', handoff = null }) {
  const env = nfcEnvironment();
  const canWrite = env === 'android-web-nfc';
  const handoffCanvas = useRef(null);
  const [copied, setCopied] = useState(false);
  const [state, setState] = useState('idle'); // idle | waiting | done | error
  const [message, setMessage] = useState('');
  const abort = useRef(null);

  useEffect(() => () => abort.current?.abort(), []);
  useEffect(() => {
    if (handoff && handoffCanvas.current) void QRCode.toCanvas(handoffCanvas.current, handoff, { width: 160, margin: 1 });
  }, [handoff]);

  async function send() {
    try {
      if (navigator.share) await navigator.share({ title: `${branchName} feedback link`, url });
      else window.location.href = `mailto:?subject=${encodeURIComponent(`${branchName} feedback link`)}&body=${encodeURIComponent(url)}`;
    } catch (e) {
      if (e.name !== 'AbortError') window.location.href = `mailto:?subject=${encodeURIComponent(`${branchName} feedback link`)}&body=${encodeURIComponent(url)}`;
    }
  }

  async function copyPage() {
    try { await navigator.clipboard.writeText(window.location.href); setCopied(true); } catch { setCopied(false); }
  }

  async function write() {
    setState('waiting');
    abort.current = new AbortController();
    try {
      const reader = new window.NDEFReader();
      await reader.write({ records: [{ recordType: 'url', data: url }] }, { overwrite: true, signal: abort.current.signal });
      setState('done');
    } catch (e) {
      if (e.name === 'AbortError') { setState('idle'); return; }
      setMessage(ERRORS[e.name] ?? 'Could not write to the card.');
      setState('error');
    }
  }

  return (
    <section className="nfc" aria-labelledby="nfc-h">
      <h3 id="nfc-h">Write to an NFC card</h3>
      {!canWrite ? (
        <>
          <p className="small muted">Writing from the browser only works in Chrome on an Android phone, on the live (HTTPS) site. Use one of these routes.</p>
          <details className="nfc-steps" open={env === 'ios' || env === 'desktop'}>
            <summary>Other ways to write this card</summary>
            <ol className="small">{(STEPS[env] ?? STEPS.desktop).map((t) => <li key={t}>{t}</li>)}</ol>
          </details>
          <div className="row nfc-actions">
            <button type="button" className="btn" onClick={() => void send()}>Send link</button>
            {env === 'android-other' && <button type="button" className="btn" onClick={() => void copyPage()}>{copied ? 'Copied ✓' : 'Copy page address'}</button>}
          </div>
          {handoff && (
            <div className="nfc-handoff">
              <canvas ref={handoffCanvas} role="img" aria-label="QR code to open this page on an Android phone" />
              <p className="small muted">Scan with an Android phone to write this card</p>
            </div>
          )}
        </>
      ) : (
        <>
          <p className="small muted">Hold a blank or reusable NFC card to the back of this phone. Anything already on the card is replaced.</p>
          {isLocalHost() && (
            <p className="alert" role="alert">This page is running on a local address, so the card would open a link that only works on this network. Write cards from the live site.</p>
          )}
          {state === 'waiting' ? (
            <div className="row">
              <p role="status" style={{ flex: 1 }}>Hold the card against the back of your phone…</p>
              <button type="button" className="btn" onClick={() => abort.current?.abort()}>Cancel</button>
            </div>
          ) : (
            <button type="button" className="btn primary" onClick={() => void write()}>{state === 'done' ? 'Write another card' : 'Write to NFC card'}</button>
          )}
          {state === 'done' && <p className="alert ok" role="status">Done. The card now opens this branch's feedback form. Tap it with a phone to test it.</p>}
          {state === 'error' && <p className="alert" role="alert">{message}</p>}
        </>
      )}
    </section>
  );
}
