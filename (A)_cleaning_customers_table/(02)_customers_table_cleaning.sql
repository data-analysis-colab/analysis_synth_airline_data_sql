-- general diagnosis, add data_quality column
alter table customers
add column data_quality text;

update customers
set data_quality = case
    when email is null and date_of_birth is null and phone is null then 'email_dob_phone_missing'
    when email is null and date_of_birth is null then 'email_dob_missing'
    when email is null and phone is null then 'email_phone_missing'
    when email is null then 'email_missing'
    when date_of_birth is null and phone is null then 'dob_phone_missing'
    when date_of_birth is null then 'dob_missing'
    when phone is null then 'phone_missing'
    else 'complete'
end
where true; -- suppresses warning about updating the table without where statement

select
    data_quality,
    count(*) as count,
    round(count(*) * 100.0 / (select count(*) from customers), 2) as percent
from customers
group by data_quality;

-----------------------------------------------------------------------------------------------------------------------

-- diagnosis emails: common typos & invalid format
with anomalies as (
    select
        count(*) filter (where email ~* '@{2,}') as multi_at,
        count(*) filter (where email ~* '\.{2,}') as multi_dot,
        count(*) filter (where email ~* '@gnail\.com') as gnail,
        count(*) filter (where email ~* '\.comcom') as comcom,
        count(*) filter (where email ~* '@gmal\.com') as gmal,
        count(*) filter (where email ~* '@hotmial\.com') as hotmial,
        count(*) filter (where email ~* '@yaho\.') as yaho,
        count(*) filter (where email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') as invalid_format
    from customers_noisy_backup
    where email is not null
)
select
    multi_at + multi_dot + gnail + comcom + gmal + hotmial + yaho as sum_anomalies,
    invalid_format
from anomalies;

-- clean typos
update customers set email = regexp_replace(email, '@{2,}', '@');
update customers set email = regexp_replace(email, '\.{2,}', '.');
update customers set email = regexp_replace(email, '\.comcom', '.com');
update customers set email = regexp_replace(email, '@gnail\.com', '@gmail.com');
update customers set email = regexp_replace(email, '@gmal\.com', '@gmail.com');
update customers set email = regexp_replace(email, '@hotmial\.com', '@hotmail.com');
update customers set email = regexp_replace(email, '@yaho\.', '@yahoo.com');

-- verify cleaning, compare with backup
select
    'backup' as version,
    count(*) filter (where email ~* '@{2,}') as multi_at,
    count(*) filter (where email ~* '\.{2,}') as multi_dot,
    count(*) filter (where email ~* '@gnail\.com') as gnail,
    count(*) filter (where email ~* '\.comcom') as comcom,
    count(*) filter (where email ~* '@gmal\.com') as gmal,
    count(*) filter (where email ~* '@hotmial\.com') as hotmial,
    count(*) filter (where email ~* '@yaho\.') as yaho,
    count(*) filter (where email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') as invalid_format
from customers_noisy_backup
where email is not null
union all
select
    'clean' as version,
    count(*) filter (where email ~* '@{2,}') as multi_at,
    count(*) filter (where email ~* '\.{2,}') as multi_dot,
    count(*) filter (where email ~* '@gnail\.com') as gnail,
    count(*) filter (where email ~* '\.comcom') as comcom,
    count(*) filter (where email ~* '@gmal\.com') as gmal,
    count(*) filter (where email ~* '@hotmial\.com') as hotmial,
    count(*) filter (where email ~* '@yaho\.') as yaho,
    count(*) filter (where email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') as invalid_format
from customers
where email is not null;

-- set emails which still lack a valid format to null
update customers
set email = null
where email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';

-- verify, compare with backup
select
    'backup' as version,
    count(*) filter (where email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$') as invalid_format
from customers_noisy_backup
where email is not null
union all
select
    'clean' as version,
    count(*) filter (where email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$') as invalid_format
from customers
where email is not null;

-- update data_quality column for missing email flags
update customers
set data_quality = case
    when email is null and date_of_birth is null and phone is null then 'email_dob_phone_missing'
    when email is null and date_of_birth is null then 'email_dob_missing'
    when email is null and phone is null then 'email_phone_missing'
    when email is null then 'email_missing'
    when date_of_birth is null and phone is null then 'dob_phone_missing'
    when date_of_birth is null then 'dob_missing'
    when phone is null then 'phone_missing'
    else 'complete'
end
where true;

-----------------------------------------------------------------------------------------------------------------------

-- find unique nationality entries and pick the valid ones for the next query
select distinct nationality
from customers;

-- diagnosis nationality
with invalid_nationalities as (
    select distinct
        nationality,
        count(*) as count
    from customers_noisy_backup
    where nationality not in
        ('Australia', 'Austria', 'Brazil', 'Canada', 'Denmark', 'Finland', 'France',
         'Germany', 'Italy', 'Netherlands', 'Norway', 'Poland', 'Portugal', 'Spain',
         'Sweden', 'Switzerland', 'United Kingdom', 'United States')
    group by nationality
)
select distinct
    sum(count)
from invalid_nationalities;

-- clean nationality for missing title casing
update customers set nationality = initcap(nationality);

-- verify (should return 0 rows)
select distinct
    nationality,
    count(*) as count
from customers
where nationality not in
    ('Australia', 'Austria', 'Brazil', 'Canada', 'Denmark', 'Finland', 'France',
     'Germany', 'Italy', 'Netherlands', 'Norway', 'Poland', 'Portugal', 'Spain',
     'Sweden', 'Switzerland', 'United Kingdom', 'United States')
group by nationality;

-----------------------------------------------------------------------------------------------------------------------

-- diagnosis names, missing title casing
select
    full_name,
    count(*) over () as count
from customers_noisy_backup
where full_name is not null
  and full_name != initcap(full_name);

-- find names that contain lowercase particles not at the start
select
    full_name,
    initcap(full_name) as initcap_version
from customers_noisy_backup
where full_name ~* '\y(de|del|de la|de los|de las|van|von|vom|zu|zum|zur|da|dos|das|du|des|le|la|les|di|della|delle|auch)\y'
  and full_name !~* '^[[:space:]]*(de|del|van|von|zu|zur|da|du|di)\y';

-- finding distinct family names starting with "mc"
select distinct regexp_replace(full_name, '.*\s+', '') as last_name
from customers_noisy_backup
where regexp_replace(full_name, '.*\s+', '') ilike 'mc%';

-- find family name "Le"
select distinct full_name
from customers_noisy_backup
where regexp_replace(full_name, '.*\s+', '') = 'le' OR
      regexp_replace(full_name, '.*\s+', '') = 'Le';

-- Create function to clean and properly title-case full names
-- while respecting linguistic exceptions (e.g., "de", "van")
-- and handling specific edge cases (e.g., McDonald).
create or replace function smart_initcap(name text)
returns text as $$
declare
  -- Index of the last word in the name
  last_index int;

  -- Array of words obtained by splitting the input name on whitespace
  words text[];

  -- Final reconstructed name
  result text := '';

  -- Words that should remain lowercase unless they appear first
  -- (common particles in surnames across languages)
  lower_exceptions text[] := array[
    'de', 'del', 'de la', 'de los', 'de las',
    'van', 'von', 'vom', 'zu', 'zum', 'zur',
    'da', 'dos', 'das', 'du', 'des', 'le', 'la', 'les',
    'di', 'della', 'delle', 'der', 'den', 'auch', '''t', 'und'
  ];

  -- Words beginning with "Mc" that require a specific predefined capitalization
  mc_exceptions text[] := array['McDonald', 'McCarthy', 'McKenzie', 'McLean'];

begin
  -- Split name into words
  words := regexp_split_to_array(name, '\s+');

  -- Determine last index for later special-case handling
  last_index := array_upper(words, 1);

  -- Iterate through all name components
  for i in array_lower(words,1)..array_upper(words,1) loop

    -- Capitalize words unless they belong to lower-exceptions
    -- Note: first word should *always* be capitalized
    if i = 1 or not (words[i] = any(lower_exceptions)) then

      -- Check if the word is a known "Mc" capitalization exception
      if words[i] = any(mc_exceptions) then
        -- If yes, keep as-is (already correctly capitalized)
        null;
      else
        -- Otherwise apply standard title casing
        words[i] := initcap(words[i]);
      end if;

    else
      -- Lowercase designated exception particles (e.g., "de", "von")
      words[i] := lower(words[i]);
    end if;

    -- Special adjustments for final word in name
    if i = last_index then
        -- Some particles conventionally capitalize when at the end
        if words[i] = 'delle' then
            words[i] := 'Delle';
        elsif words[i] = 'le' then
            words[i] := 'Le';
        end if;
    end if;

    -- Append processed word to result string
    result := result || words[i] || ' ';
  end loop;

  -- Trim trailing space before returning result
  return trim(result);
end;
$$ language plpgsql immutable;

-- preview changes
-- 1) lower case particles excepted
select distinct
    full_name,
    smart_initcap(full_name) AS smart_initcap_version
from customers_noisy_backup
where full_name ~* '\y(de|del|de la|de los|de las|van|von|vom|zu|zum|zur|da|dos|das|du|des|le|la|les|di|della|delle|auch)\y'
  and full_name !~* '^[[:space:]]*(de|del|van|von|zu|zur|da|du|di)\y'
  and full_name = lower(full_name);

-- 2) special handling of family names containing "mc"
select distinct
    full_name,
    smart_initcap(full_name) AS smart_initcap_version
from customers_noisy_backup
where regexp_replace(full_name, '.*\s+', '') ilike 'mc%';

-- apply the changes
update customers
set full_name = smart_initcap(full_name);

-- sample verification
select distinct
    cnb.full_name as noisy,
    c.full_name as clean
from customers_noisy_backup cnb
join customers c on cnb.customer_id = c.customer_id
where cnb.full_name = lower(cnb.full_name);