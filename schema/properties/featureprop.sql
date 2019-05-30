create schema if not exists flybase;
grant usage on schema flybase to PUBLIC;

create or replace function flybase.get_featureprop(id text, type text)
returns setof featureprop as $$
  select fp.*
    from feature f join featureprop fp on f.feature_id = fp.feature_id
                   join cvterm cvt on fp.type_id = cvt.cvterm_id
    where f.uniquename = $1
      and f.is_obsolete = false
      and cvt.name similar to $2
      and cvt.is_obsolete = 0
  ;
$$ language sql stable;

