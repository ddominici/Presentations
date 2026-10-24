/*
 * SQL Start! 2025 - PostgreSQL temporal data
 * Date and time formats
 */

-- Date construction 
select date '2025-06-13';
select '2025-06-13'::date;
select '2025-13-06'::date;
select date 'Jun 13, 2025';
select date '2025/10/21';
select date '151021';
select date 'Jun 13, 2025 BC';
select date 'J10';
select date 'infinity';
select date '-infinity';
select date 'epoch';

-- Time construction
select time '12:34:56.789';
select '12:34:56.789'::time;
select time '34:56.789';
select time '12:34';
select time (1) '12:34:00.199';
select time '010203';
select time '3:14pm';
select time 'allballs';
select time '0:0';

-- Timestamp construction
select timestamp '2025-06-13 12:34:56.789';
select timestamp '2025-06-13';
select timestamp '-infinity';
select timestamp 'epoch';
select timestamp 'now';

-- Interval construction
select interval '1 year 2 months 3 days';
select interval '1 year 2 months 3 days ago';
select interval '1 12:34';
select interval '1-1 12:34';
select interval '12:34';
select interval 'P1Y2M3DT4H5M6.789S';
select interval 'P1Y2M3M4M5M10Y';
select interval 'P0001-02-03T04:05:06';
select date '2017-02-01' + interval '1 month';
select date '2017-03-01' + interval '1 month';
select interval '1 day' - interval '300 hours';
select interval '1-2 4:5:6.789' year to month;
select interval '1-2 4:5:6.789' day to minute;
create table vehicle_rentals (is_late_by interval hour);
select interval '1-2 4:5:6.789' day to second (1);

-- Date operators
select date '1985-06-13' + 5;
select date '1985-10-26' - 5;
select date '1985-06-13' + interval '30 years';
select date '2025-06-13' - interval '30 years';
select date '2025-06-13' + time '01:00';
select date '2025-10-26' - date '2025-06-13';
select date '2025-10-26' = date '2025-06-13';
select date '2025-10-26' < date '2025-06-13';

-- Date functions
select make_date(2025, 10, 21);
select date_part('year', date '2016-06-13');
select extract('month' from date '2016-06-13');
select date_part('dow', date '2025-06-13');
select date_part('epoch', date '2025-06-13');
select isfinite(date '-infinity');
select to_char(date '2025-06-13', 'Mon-YY');
select to_char(date '2025-06-13', 'Month YYYY BC, day DD');
select to_char(date '2025-06-13', 'Month YYYY BC, "day" DD');
select to_char(date '2025-06-13', 'FMMonth YYYY BC, "day" DD');
select to_char(date '2025-06-13', 'FMMonth YYYY BC, DDth "day"');
select to_char(date '2025-06-13', 'FMMonth YYYY BC, DDth "day" (DAY of "w"eek WW)');
select to_date('21st October 2025 BC', 'DDth Month YYYY BC');
select to_date('2025-20-40', 'YYYY-MM-DD');

-- Time operators
select time '01:00' + interval '4 hours';
select time '15:30' - time '12:00';
select time '15:30' + interval '1 year';
select time '3:00' = time '3:01';
select time '3:00' < time '3:01';

-- Time functions
select make_time(1, 2, 3.456);
select date_part('hour', time '1:2:3.456789');
select date_part('minute', time '1:2:3.456789');
select date_part('second', time '1:2:3.456789');
select date_part('millisecond', time '1:2:3.456789');
select date_part('microsecond', time '1:2:3.456789');
select date_trunc('hour', time '01:02:56.123789');
select date_trunc('millisecond', time '01:02:56.123789');
select to_char(time '15:02:03.456', 'HH.MI AM (SSSS"s" "since midnight")');

-- Timestamp operators
select timestamp '2025-06-13 01:00' + interval '2 days 4 hours';
select timestamp '2025-06-13 01:00' - time '03:30';
select timestamp '2025-10-26 01:00' - timestamp '2025-06-13 03:00';
select timestamp '2025-10-26 01:00' = timestamp '2025-06-13 03:00';
select timestamp '2025-10-26 01:00' < timestamp '2025-06-13 03:00';

-- Timestamp functions
select make_timestamp(2025, 10, 21, 1, 2, 3.4);
select to_timestamp(1490732210.566);
select age('1980-01-01 00:00:00');
select age('2025-10-26 0:0:0', '2025-06-13 2:0:0');
select age('2025-11-22', '2025-06-13');
select date_trunc('year', timestamp '2025-06-13 01:02:03');
select date_trunc('hour', timestamp '2025-06-13 01:02:03');
select date_trunc('month', date '2025-06-13')::date;
select (date_trunc('month', date '2025-06-13') + interval '1 month -1 day')::date;
select to_char(timestamp '2025-06-13 01:02:03', 'Mon-YY HH24:MI');
select to_timestamp('21st October 2025 BC 12:30', 'DDth Month YYYY BC HH24:MI');
select to_timestamp('2025-20-40', 'YYYY-MM-DD');

-- Date and timestamp gotchas
select age(date '2017-02-28', date '2016-02-28');
select date '2017-02-28' - date '2016-02-28';

-- Interval operators
select interval '1 month' + interval '1 hour';
select interval '1 year' - interval '5 months';
select interval '1 year' + interval '4000 days';
select -interval '1 hour';
select 10 * interval '1 hour';
select 0.3 * interval '1 year';
select interval '1 year' / 3.5;
select interval '1 year' = interval '360 days';

-- Interval functions
select make_interval(1, 2, 0, 3, 4, 5, 6.789);
select make_interval(days => 20, months => 2); 
select justify_hours('1 day 49 hours');
select justify_days('35 days');
select justify_interval('35 days 49 hours');
select to_char(interval '15:02:03.456', 'HH.MI AM (SSSS"s" "since midnight")');

