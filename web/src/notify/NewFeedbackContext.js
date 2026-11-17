import { createContext, useContext } from 'react';

// ready: last-seen time loaded. newCount/newLow: responses (and those below 4 stars) since seenAt.
// items: the latest few new responses.
export const NewFeedbackContext = createContext({
  ready: false, seenAt: null, newCount: 0, newLow: 0, items: [], markSeen: async () => {},
});

export const useNewFeedback = () => useContext(NewFeedbackContext);
