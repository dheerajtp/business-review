import { useEffect, useRef, useState } from 'react';

const ERRORS = {
  NotAllowedError: 'NFC permission was denied. Allow NFC for this site in the browser settings and try again.',
  NotSupportedError: 'NFC is switched off or not available on this phone. Turn it on in the phone settings.',
  NetworkError: 'The card moved away or could not be written. Hold it steady against the back of the phone and try again.',
};
// Browsers only expose NFC writing on Chrome for Android, on a secure (HTTPS) page.
const canWrite = () => 'NDEFReader' in window && window.isSecureContext;
const isLocalHost = () => /^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(window.location.hostname);

export default function NfcWriter({ url }) {
  const [state, setState] = useState('idle'); // idle | waiting | done | error
  const [message, setMessage] = useState('');
  const abort = useRef(null);

  useEffect(() => () => abort.current?.abort(), []);

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
      {!canWrite() ? (
        <p className="small muted">
          Writing a card from the browser only works in Chrome on an Android phone, on the live (HTTPS) site. On this device, copy the link and write it with any NFC writing app.
        </p>
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
