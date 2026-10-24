/*
 * SQL Start! 2025 - PostgreSQL temporal data
 * Ranges
 */

-- Range construction
select numrange '[1, 10)';
select numrange(1, 10);
select numrange(1, 10, '[]');
select numrange '[1,)';
select numrange '(,10)';
select numrange '(,)';
select numrange 'empty';

-- Date range construction
select daterange '[today, infinity)';
select daterange '[today,)';
select daterange '[today, 2030-01-01)';
select daterange('yesterday', 'tomorrow', '[]');

-- Range functions
select lower(daterange '[today, 2030-01-01)');
select upper(daterange '[today, 2030-01-01)');
select lower_inc(daterange '[today, 2030-01-01)');
select upper_inc(daterange '[today, 2030-01-01)');
select lower_inf(daterange '[today, 2030-01-01)');
select upper_inf(daterange '[today, 2030-01-01)');
select isempty(daterange '[today, 2030-01-01)');
select range_merge(daterange '[2025-06-13, 2025-06-22)', 
				   daterange '[2025-06-25, 2025-06-26)');

-- Range operators
select daterange '[2025-06-13, 2025-06-30)' = daterange '[2025-06-26, 2025-11-30)';
select daterange '[2025-06-13, 2025-06-30)' != daterange '[2025-06-26, 2025-11-30)';
select daterange '[2025-06-13, 2025-06-30)' && daterange '[2025-06-26, 2025-11-30)';
select daterange '[2025-06-13, 2025-06-26)' @> date '2025-06-22';
select date '2025-06-22' <@ daterange '[2025-06-13, 2025-06-26)';
select daterange '[2025-06-13, 2025-06-16)' @> daterange '[2025-06-22, 2025-06-24)';
select daterange '[2025-06-14, 2025-06-24)' <@ daterange '[2025-06-13, 2025-06-26)';
select daterange '[2025-06-13, 2025-06-25)' << daterange '[2025-06-26, 2025-11-30)';
select daterange '[2025-06-26, 2025-11-30)' >> daterange '[2025-06-13, 2025-06-25)';
select daterange '[2025-06-13, 2025-06-25)' &< daterange '[2025-06-26, 2025-11-30)';
select daterange '[2025-06-13, 2025-06-25)' &> daterange '[2025-06-26, 2025-11-30)';
select daterange '[2025-06-13, 2025-06-25)' -|- daterange '[2025-06-25, 2025-06-26)';
select daterange '[2025-06-25, 2025-06-26)' -|- daterange '[2025-06-13, 2025-06-25)';
select daterange '[2025-06-13, 2025-06-23)' + daterange '[2025-06-25, 2025-06-26)';
select daterange '[2025-06-13, 2025-06-23)' * daterange '[2025-06-22, 2025-06-26)';
select daterange '[2025-06-13, 2025-06-31)' - daterange '[2025-06-25, 2025-11-30)';
select daterange '[2025-06-13, 2025-06-31)' - daterange '[2025-06-22, 2025-06-25)';

-- Timestamp range construction
select tsrange '[2025-06-13 00:00:00, 2025-06-26 15:30:45)';
select tsrange '[2025-06-13 00:00:00, 2025-06-26 15:30:45]';

-- Time range construction
create type timerange as range (subtype = time);
select timerange '[03:00, 03:30)' * timerange '[03:20, 04:00)';

-- Overlaps operator
select (date '2025-06-13', date '2025-06-30') overlaps (date '2025-06-26', date '2025-11-30');
select (date '2025-06-13', interval '9 days') overlaps (date '2025-06-26', interval '1 month');

-- Current time 
select date 'today';
select date 'yesterday';
select date 'tomorrow';
select timestamp 'yesterday';
select time 'now';
select timestamp 'now';

begin;
select now();
select now(); 
select now(); 
rollback;

begin;
select clock_timestamp();
select clock_timestamp(); 
select clock_timestamp(); 
rollback;

select statement_timestamp(), pg_sleep(1), statement_timestamp();
select clock_timestamp(), pg_sleep(1), clock_timestamp();

create table aeons (num int, created_at timestamp default 'now', updated_at timestamp default now());
insert into aeons(num) values (1);
insert into aeons(num) values (2);
insert into aeons(num) values (3);

-- Sequence generation
select * 
from generate_series(timestamp '2025-06-13', timestamp '2025-06-26', interval '2 hours');
select s.d::date 
from generate_series(timestamp '2025-06-13', timestamp '2025-06-26', interval '1 day') as s(d);

select date '2025-06-13' + s.i 
from generate_series(0, 5, 1) as s(i);

select id, created_at::date, start_at, finish_at 
from vehicle_usage 
where id = 'LP8574' 
order by created_at;

select d::date as created_on 
from generate_series(date '2017-03-01', date '2017-03-10', interval '1 day') s(d);

with dates as (
    select d::date as created_on 
    from generate_series(date '2017-03-01', date '2017-03-10', interval '1 day') s(d)
)
select id, created_on, start_at, finish_at
from dates
left join vehicle_usage on created_on = created_at::date
where id = 'LP8574' or id is null
order by created_on;

with dates as (
    select d::date as created_on 
    from generate_series(date '2017-03-01', date '2017-03-10', interval '1 day') s(d)
)
select id, created_on, start_at, finish_at
from dates
left join vehicle_usage on created_on = created_at::date and id = 'LP8574'
order by created_on;

with dates as (
    select d::date as created_on 
    from generate_series(date '2017-03-01', date '2017-03-10', interval '1 day') s(d)
    where date_part('isodow', d) < 6
)
select id, created_on, start_at, finish_at
from dates
left join vehicle_usage on created_on = created_at::date and id = 'LP8574'
order by created_on;