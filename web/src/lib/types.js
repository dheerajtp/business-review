 

export const QUESTION_TYPE_LABEL = {
  single: 'Single choice',
  multi: 'Multiple choice',
  scale: '1–5 scale',
  text: 'Open text',
};
export const SOFT_QUESTION_LIMIT = 5;

export const EMPTY_DRAFT = { rating: 0, answers: {}, comment: '', contact: '' };
export const RATING_LABEL = ['', 'Poor', 'Fair', 'Okay', 'Good', 'Excellent'];

export const isAnswered = (v) =>
  v !== undefined && v !== '' && !(Array.isArray(v) && v.length === 0);
