/*
 * SQL Night - PostgreSQL temporal data
 * Demo 03 - Time zones
 */

-- Time zone aware types

select timestamptz '2025-06-13 01:00:00+5:30';
select timestamptz '2025-06-13 01:00:00+1:23:45';
select timestamptz '2025-06-13 01:00:00 Europe/Rome';

-- Time zone views

select * from pg_timezone_names;
select * from pg_timezone_abbrevs;

-- Calculations

select make_timestamptz(2025, 06, 13, 1, 2, 3.4);
select make_timestamptz(2025, 06, 13, 1, 2, 3.4, 'NZ');

-- Set time zone

set time zone 'NZ';
set time zone 'US/Pacific';

-- Time zone conversions

set time zone 'NZ';
select timestamp '2025-06-13 10:00:00' at time zone 'PRC';
select timezone('PRC', timestamp '2025-06-13 10:00:00');
select timestamptz '2025-06-13 10:00:00+8' at time zone 'NZ';
select timestamptz '2025-06-13 10:00:00+8' at time zone interval '5:30';

-- Gotchas

set time zone 'US/Eastern';
select age(timestamptz '2017-07-01 12:00:00', timestamptz '2017-03-01 12:00:00'); -- 4 months
select timestamptz '2017-07-01 12:00:00' - timestamptz '2017-03-01 12:00:00'; -- not 4 months

select * from pg_timezone_names where name = 'CET'; -- entry exists
select * from pg_timezone_abbrevs where abbrev = 'CET'; -- also exists
set time zone 'UTC';
select timestamptz '2017-04-10 0:0:0 CET'; -- uses abbreviation, not time zone