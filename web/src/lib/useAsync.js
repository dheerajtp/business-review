import { useCallback, useEffect, useState } from 'react';
import { errorMessage } from './format';

/** Runs `fn` on mount and whenever `deps` change; `reload()` re-runs it. */
export function useAsync(fn, deps) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    setLoading(true);
    fn().then(
      (d) => { if (live) { setData(d); setError(null); setLoading(false); } },
      (e) => { if (live) { setError(errorMessage(e)); setLoading(false); } },
    );
    return () => { live = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);

  const reload = useCallback(() => setTick((t) => t + 1), []);
  return { data, error, loading, reload };
}
