const PATHS = {
  chart: ['M3 3v18h18', 'M7 15l4-4 3 3 5-6'],
  feedback: ['M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z'],
  categories: ['M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L2 12V2h10l8.6 8.6a2 2 0 0 1 0 2.8z', 'M7 7h.01'],
  keywords: ['M4 9h16M4 15h16', 'M10 3L8 21M16 3l-2 18'],
  ai: ['M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z', 'M19 16l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z'],
  companies: ['M4 21V3h10v18', 'M14 9h6v12', 'M8 7h2M8 11h2M8 15h2', 'M3 21h18'],
  menu: ['M4 6h16M4 12h16M4 18h16'],
  close: ['M6 6l12 12M18 6L6 18'],
  bell: ['M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9', 'M13.7 21a2 2 0 0 1-3.4 0'],
  collapse: ['M11 17l-5-5 5-5', 'M18 17l-5-5 5-5'],
  chevron: ['M6 9l6 6 6-6'],
  star: ['M12 2.5l2.9 6.1 6.6.9-4.8 4.6 1.2 6.6L12 17.6 6.1 20.7l1.2-6.6L2.5 9.5l6.6-.9z'],
  signout: ['M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4', 'M16 17l5-5-5-5', 'M21 12H9'],
};

export default function NavIcon({ name }) {
  return (
    <svg className="icon" viewBox="0 0 24 24" aria-hidden="true">
      {PATHS[name].map((d) => <path key={d} d={d} />)}
    </svg>
  );
}
