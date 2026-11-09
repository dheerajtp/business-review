import { createContext, useContext } from 'react';

// ready: last-seen time loaded. newCount/newLow: responses (and those below 4 stars) since seenAt.
// items: the latest few new responses. pendingRequests: question requests awaiting review (super admin only).
export const NewFeedbackContext = createContext({
  ready: false, seenAt: null, newCount: 0, newLow: 0, items: [], pendingRequests: 0, markSeen: async () => {},
});

export const useNewFeedback = () => useContext(NewFeedbackContext);
