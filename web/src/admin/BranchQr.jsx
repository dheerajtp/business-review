import { useEffect, useRef, useState } from 'react';
import QRCode from 'qrcode';
import NfcWriter from './NfcWriter';
import Modal from '../ui/Modal';
import { feedbackUrl } from '../lib/format';

export default function BranchQr({ branch, onClose }) {
  const canvas = useRef(null);
  const [copied, setCopied] = useState(false);
  const url = feedbackUrl(branch.slug);

  useEffect(() => {
    if (canvas.current) void QRCode.toCanvas(canvas.current, url, { width: 220, margin: 2 });
  }, [url]);

  function download() {
    const a = document.createElement('a');
    a.href = canvas.current.toDataURL('image/png');
    a.download = `${branch.name.replace(/[^a-z0-9]+/gi, '-').toLowerCase()}-qr.png`;
    a.click();
  }

  async function copy() {
    try { await navigator.clipboard.writeText(url); setCopied(true); } catch { setCopied(false); }
  }

  return (
    <Modal title={`${branch.name}: NFC & QR`} onClose={onClose}>
      <div className="qr">
        <canvas ref={canvas} role="img" aria-label={`QR code for ${branch.name}`} />
        <p className="small muted">Write this link to the NFC tag. The QR code is the camera backup.</p>
        <p className="mono">{url}</p>
      </div>
      <NfcWriter url={url} />
      <div className="actions">
        <button type="button" className="btn" onClick={() => void copy()}>{copied ? 'Copied ✓' : 'Copy link'}</button>
        <a className="btn" href={url} target="_blank" rel="noopener noreferrer">Open</a>
        <button type="button" className="btn primary" onClick={download}>Download QR</button>
      </div>
    </Modal>
  );
}
