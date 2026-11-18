-- One-off cleanup: remove categories that have no subcategory rows (active or archived).
-- Keywords tagged to those categories are not deleted; they become General (category_id null).
-- Categories that have subcategories are untouched. Companies reference subcategories,
-- so no company can point at a deleted category. Idempotent; no schema change.
--
-- Preview the rows that will be removed before applying:
--   select name from categories c where not exists (select 1 from subcategories s where s.category_id = c.id);

update keywords set category_id = null
where category_id in (
  select c.id from categories c
  where not exists (select 1 from subcategories s where s.category_id = c.id)
);

delete from categories c
where not exists (select 1 from subcategories s where s.category_id = c.id);
