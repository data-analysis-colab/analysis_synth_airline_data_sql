-- back up relevant customer columns before cleaning
create table customers_noisy_backup as
select customer_id, full_name, email, phone, date_of_birth, nationality
from customers;

-- restore 'noisy' columns, if necessary
update customers c
set
    full_name = b.full_name,
    email = b.email,
    phone = b.phone,
    date_of_birth = b.date_of_birth,
    nationality = b.nationality
from customers_noisy_backup b
where c.customer_id = b.customer_id;