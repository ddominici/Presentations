-- PostgreSQL Temporal Data Complete Example
-- Conference Presentation: Advanced Temporal Data Management
-- Author: Danilo Dominici
-- Description: Full implementation of temporal tables without extensions

-- ================================================================
-- PART 1: DATABASE SETUP AND TEMPORAL FOUNDATION
-- ================================================================

-- Create the temporal database (run as superuser if needed)
-- CREATE DATABASE temporaldata;
-- \c temporaldata;

-- Show enabled extensions
SHOW azure.extensions;

-- Enable required extensions for advanced functionality
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- ================================================================
-- PART 2: SYSTEM-VERSIONED TEMPORAL TABLES (BITEMPORAL)
-- ================================================================

drop table if exists salary_history cascade;
drop table if exists employees cascade;
drop table if exists employees_history cascade;
drop table if exists departments cascade;
drop table if exists department_assignments cascade;

-- Base employee table with system versioning
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    employee_uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    department_id INTEGER,
    salary DECIMAL(10,2),
    hire_date DATE NOT NULL,
    
    -- System time columns (when the record was valid in the system)
    sys_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    sys_end TIMESTAMP WITH TIME ZONE DEFAULT 'infinity'::timestamp NOT NULL,

    -- Valid time columns (when the data was valid in reality)
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_to TIMESTAMP WITH TIME ZONE DEFAULT 'infinity'::timestamp NOT NULL,
    
    -- Metadata
    created_by VARCHAR(100) DEFAULT CURRENT_USER,
    operation_type CHAR(1) DEFAULT 'I' CHECK (operation_type IN ('I', 'U', 'D')),
    
    -- Constraints
    CONSTRAINT chk_sys_time CHECK (sys_start < sys_end),
    CONSTRAINT chk_valid_time CHECK (valid_from < valid_to),
    EXCLUDE USING gist (
        employee_uuid WITH =,
        tstzrange(sys_start, sys_end, '[)') WITH &&
    )
);

-- History table for employees
CREATE TABLE employees_history (
    LIKE employees INCLUDING ALL
);

-- ================================================================
-- PART 3: APPLICATION-TIME PERIOD TABLES
-- ================================================================

-- Department assignments with application-time periods
CREATE TABLE department_assignments (
    assignment_id SERIAL PRIMARY KEY,
    employee_uuid UUID NOT NULL REFERENCES employees(employee_uuid),
    department_id INTEGER NOT NULL,
    position_title VARCHAR(200) NOT NULL,
    assignment_period TSTZRANGE NOT NULL,
    salary_during_period DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT CURRENT_USER,
    -- Prevent overlapping assignments for same employee
    EXCLUDE USING gist (
        employee_uuid WITH =,
        assignment_period WITH &&
    )
);

-- Salary history with effective periods
CREATE TABLE salary_history (
    salary_id SERIAL PRIMARY KEY,
    employee_uuid UUID NOT NULL REFERENCES employees(employee_uuid),
    salary_amount DECIMAL(10,2) NOT NULL,
    effective_period TSTZRANGE NOT NULL,
    reason VARCHAR(500),
    approved_by VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- Prevent overlapping salary periods
    EXCLUDE USING gist (
        employee_uuid WITH =,
        effective_period WITH &&
    )
);

-- ================================================================
-- PART 4: TEMPORAL FUNCTIONS AND TRIGGERS
-- ================================================================

-- Function to handle temporal updates
CREATE OR REPLACE FUNCTION handle_temporal_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert old version into history
    INSERT INTO employees_history (
        employee_id, employee_uuid, first_name, last_name, email,
        department_id, salary, hire_date,
        sys_start, sys_end, valid_from, valid_to,
        created_by, operation_type
    )
    VALUES (
        OLD.employee_id, OLD.employee_uuid, OLD.first_name, OLD.last_name, OLD.email,
        OLD.department_id, OLD.salary, OLD.hire_date,
        OLD.sys_start, CURRENT_TIMESTAMP, OLD.valid_from, OLD.valid_to,
        OLD.created_by, 'U'
    );
    
    -- Update sys_start for new version
    NEW.sys_start := CURRENT_TIMESTAMP;
	NEW.sys_end := 'infinity'::timestamp;
    NEW.operation_type := 'U';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle temporal deletes
CREATE OR REPLACE FUNCTION handle_temporal_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert deleted version into history
    INSERT INTO employees_history (
        employee_id, employee_uuid, first_name, last_name, email,
        department_id, salary, hire_date,
        sys_start, sys_end, valid_from, valid_to,
        created_by, operation_type
    )
    VALUES (
        OLD.employee_id, OLD.employee_uuid, OLD.first_name, OLD.last_name, OLD.email,
        OLD.department_id, OLD.salary, OLD.hire_date,
        OLD.sys_start, CURRENT_TIMESTAMP, OLD.valid_from, OLD.valid_to,
        OLD.created_by, 'D'
    );

    -- Aggiorna solo sys_end, non cancella fisicamente
    UPDATE employees
    SET sys_end = CURRENT_TIMESTAMP, operation_type = 'D'
    WHERE employee_id = OLD.employee_id;

    -- Impedisci la DELETE fisica
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER employees_temporal_update
    BEFORE UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION handle_temporal_update();

CREATE TRIGGER employees_temporal_delete
    BEFORE DELETE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION handle_temporal_delete();

-- ================================================================
-- PART 5: TEMPORAL QUERY HELPER FUNCTIONS
-- ================================================================

-- Function to get employee state at specific system time
CREATE OR REPLACE FUNCTION get_employee_at_system_time(
    p_employee_uuid UUID,
    p_system_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
)
RETURNS employees AS $$
DECLARE
    result employees;
BEGIN
    -- First check current table
    SELECT * INTO result
    FROM employees
    WHERE employee_uuid = p_employee_uuid
      AND sys_start <= p_system_time
      AND sys_end > p_system_time;
    
    -- If not found, check history
    IF NOT FOUND THEN
        SELECT * INTO result
        FROM employees_history
        WHERE employee_uuid = p_employee_uuid
          AND sys_start <= p_system_time
          AND sys_end > p_system_time;
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to get all employees valid at specific time
CREATE OR REPLACE FUNCTION get_employees_at_valid_time(
    p_valid_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
)
RETURNS SETOF employees AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM employees
    WHERE valid_from <= p_valid_time
      AND valid_to > p_valid_time
      AND sys_end = 'infinity'::timestamp
    UNION ALL
    SELECT *
    FROM employees_history
    WHERE valid_from <= p_valid_time
      AND valid_to > p_valid_time
      AND NOT EXISTS (
          SELECT 1 FROM employees e
          WHERE e.employee_uuid = employees_history.employee_uuid
            AND e.valid_from <= p_valid_time
            AND e.valid_to > p_valid_time
            AND e.sys_end = 'infinity'::timestamp
      );
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- PART 6: SAMPLE DATA INSERTION
-- ================================================================

-- Insert departments (reference data)
CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    manager_uuid UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO departments (department_name) VALUES
('Engineering'), ('Sales'), ('Marketing'), ('HR'), ('Finance');


-- Insert initial employees
INSERT INTO employees (first_name, last_name, email, department_id, salary, hire_date, valid_from) VALUES
('John', 'Doe', 'john.doe@company.com', 1, 75000.00, '2023-01-15', '2023-01-15 08:00:00+00'),
('Jane', 'Smith', 'jane.smith@company.com', 2, 65000.00, '2023-02-01', '2023-02-01 08:00:00+00'),
('Bob', 'Johnson', 'bob.johnson@company.com', 1, 80000.00, '2023-03-01', '2023-03-01 08:00:00+00'),
('Alice', 'Williams', 'alice.williams@company.com', 3, 60000.00, '2023-04-01', '2023-04-01 08:00:00+00');

select * from employees;
select * from departments;

-- Get employee UUIDs for reference
DO $$
DECLARE
    john_uuid UUID;
    jane_uuid UUID;
    bob_uuid UUID;
    alice_uuid UUID;
BEGIN
    SELECT employee_uuid INTO john_uuid FROM employees WHERE email = 'john.doe@company.com';
    SELECT employee_uuid INTO jane_uuid FROM employees WHERE email = 'jane.smith@company.com';
    SELECT employee_uuid INTO bob_uuid FROM employees WHERE email = 'bob.johnson@company.com';
    SELECT employee_uuid INTO alice_uuid FROM employees WHERE email = 'alice.williams@company.com';

    -- Insert department assignments
    INSERT INTO department_assignments (employee_uuid, department_id, position_title, assignment_period, salary_during_period) VALUES
    (john_uuid, 1, 'Software Engineer', '[2023-01-15 08:00:00+00, infinity)', 75000.00),
    (jane_uuid, 2, 'Sales Representative', '[2023-02-01 08:00:00+00, infinity)', 65000.00),
    (bob_uuid, 1, 'Senior Software Engineer', '[2023-03-01 08:00:00+00, infinity)', 80000.00),
    (alice_uuid, 3, 'Marketing Specialist', '[2023-04-01 08:00:00+00, infinity)', 60000.00);

    -- Insert salary history
    INSERT INTO salary_history (employee_uuid, salary_amount, effective_period, reason) VALUES
    (john_uuid, 75000.00, '[2023-01-15 08:00:00+00, infinity)', 'Initial hire'),
    (jane_uuid, 65000.00, '[2023-02-01 08:00:00+00, infinity)', 'Initial hire'),
    (bob_uuid, 80000.00, '[2023-03-01 08:00:00+00, infinity)', 'Initial hire'),
    (alice_uuid, 60000.00, '[2023-04-01 08:00:00+00, infinity)', 'Initial hire');
END $$;

select * from salary_history;

-- ================================================================
-- PART 7: TEMPORAL DATA OPERATIONS EXAMPLES
-- ================================================================

-- Simulate some temporal changes
DO $$
DECLARE
    john_uuid UUID;
BEGIN
    SELECT employee_uuid INTO john_uuid FROM employees WHERE email = 'john.doe@company.com';
    
    -- Update John's salary (creates history)
    UPDATE employees 
    SET salary = 85000.00,
        valid_from = '2024-01-01 08:00:00+00'
    WHERE employee_uuid = john_uuid;
    
    -- Add new salary history entry
    UPDATE salary_history 
    SET effective_period = '[2023-01-15 08:00:00+00, 2024-01-01 08:00:00+00)'
    WHERE employee_uuid = john_uuid;
    
    INSERT INTO salary_history (employee_uuid, salary_amount, effective_period, reason, approved_by) VALUES
    (john_uuid, 85000.00, '[2024-01-01 08:00:00+00, infinity)', 'Annual raise', 'manager@company.com');
END $$;


select * from employees;
select * from salary_history;

-- ================================================================
-- PART 8: TEMPORAL QUERY EXAMPLES
-- ================================================================

-- Create views for easier querying

-- Current state view (most commonly used)
CREATE VIEW current_employees AS
	SELECT e.employee_id, e.employee_uuid, e.first_name, e.last_name, e.email,
	       e.department_id, d.department_name, e.salary, e.hire_date,
	       e.valid_from, e.valid_to, e.sys_start
	FROM employees e
	LEFT JOIN departments d ON e.department_id = d.department_id
	WHERE e.sys_end = 'infinity'::timestamp
	  AND e.valid_to = 'infinity'::timestamp;

-- Historical view (includes all versions)
CREATE VIEW all_employee_versions AS
	SELECT e.employee_id, e.employee_uuid, e.first_name, e.last_name, e.email,
	       e.department_id, e.salary, e.hire_date,
	       e.valid_from, e.valid_to, e.sys_start, e.sys_end, e.operation_type,
	       'current' as source_table
	FROM employees e
	UNION ALL
	SELECT h.employee_id, h.employee_uuid, h.first_name, h.last_name, h.email,
	       h.department_id, h.salary, h.hire_date,
	       h.valid_from, h.valid_to, h.sys_start, h.sys_end, h.operation_type,
	       'history' as source_table
	FROM employees_history h;

-- Salary audit view
CREATE VIEW salary_audit AS
	SELECT e.first_name, e.last_name, e.email,
	       sh.salary_amount, sh.effective_period,
	       lower(sh.effective_period) as effective_from,
	       upper(sh.effective_period) as effective_to,
	       sh.reason, sh.approved_by, sh.created_at
	FROM salary_history sh
	JOIN employees e ON sh.employee_uuid = e.employee_uuid
	WHERE e.sys_end = 'infinity'::timestamp
	ORDER BY e.last_name, e.first_name, sh.effective_period;


-- ================================================================
-- PART 9: ADVANCED TEMPORAL QUERIES
-- ================================================================

-- Query 1: Find all employees who worked in Engineering department at any point
CREATE OR REPLACE VIEW employees_ever_in_engineering AS
	SELECT DISTINCT e.first_name, e.last_name, e.email,
	       da.assignment_period,
	       da.position_title
	FROM department_assignments da
	JOIN employees e ON da.employee_uuid = e.employee_uuid
	JOIN departments d ON da.department_id = d.department_id
	WHERE d.department_name = 'Engineering'
	  AND e.sys_end = 'infinity'::timestamp;

-- Query 2: Salary changes over time for specific employee
CREATE OR REPLACE FUNCTION get_salary_timeline(p_email VARCHAR)
RETURNS TABLE(
    employee_name TEXT,
    salary_amount DECIMAL,
    effective_from TIMESTAMP WITH TIME ZONE,
    effective_to TIMESTAMP WITH TIME ZONE,
    duration INTERVAL,
    reason VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (e.first_name || ' ' || e.last_name)::TEXT,
        sh.salary_amount,
        lower(sh.effective_period),
        CASE 
            WHEN upper(sh.effective_period) = 'infinity'::timestamp 
            THEN NULL::timestamp with time zone
            ELSE upper(sh.effective_period)
        END,
        CASE 
            WHEN upper(sh.effective_period) = 'infinity'::timestamp 
            THEN (CURRENT_TIMESTAMP - lower(sh.effective_period))
            ELSE (upper(sh.effective_period) - lower(sh.effective_period))
        END,
        sh.reason
    FROM salary_history sh
    JOIN employees e ON sh.employee_uuid = e.employee_uuid
    WHERE e.email = p_email
      AND e.sys_end = 'infinity'::timestamp
    ORDER BY lower(sh.effective_period);
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- PART 10: DEMONSTRATION QUERIES
-- ================================================================

-- Show current state of all employees
SELECT 'Current Employees' as query_description;
SELECT * FROM current_employees ORDER BY last_name, first_name;

-- Show all versions of employees (including history)
SELECT 'All Employee Versions (Current + History)' as query_description;
SELECT employee_uuid, first_name, last_name, salary, 
       sys_start, sys_end, operation_type, source_table
FROM all_employee_versions 
WHERE last_name = 'Doe'
ORDER BY sys_start;

-- Show salary audit trail
SELECT 'Salary Audit Trail' as query_description;
SELECT * FROM salary_audit;

-- Show employees in Engineering department
SELECT 'Employees Ever in Engineering' as query_description;
SELECT * FROM employees_ever_in_engineering;

-- Show salary timeline for John Doe
SELECT 'John Doe Salary Timeline' as query_description;
SELECT * FROM get_salary_timeline('john.doe@company.com');

-- ================================================================
-- PART 11: PERFORMANCE OPTIMIZATION
-- ================================================================

-- Indexes for temporal queries
CREATE INDEX idx_employees_sys_time ON employees USING gist(tstzrange(sys_start, sys_end, '[)'));
CREATE INDEX idx_employees_valid_time ON employees USING gist(tstzrange(valid_from, valid_to, '[)'));
CREATE INDEX idx_employees_uuid_sys ON employees(employee_uuid, sys_start, sys_end);

CREATE INDEX idx_employees_history_sys_time ON employees_history USING gist(tstzrange(sys_start, sys_end, '[)'));
CREATE INDEX idx_employees_history_valid_time ON employees_history USING gist(tstzrange(valid_from, valid_to, '[)'));
CREATE INDEX idx_employees_history_uuid_sys ON employees_history(employee_uuid, sys_start, sys_end);

CREATE INDEX idx_dept_assignments_period ON department_assignments USING gist(assignment_period);
CREATE INDEX idx_salary_history_period ON salary_history USING gist(effective_period);
CREATE INDEX idx_salary_history_uuid ON salary_history(employee_uuid);

-- ================================================================
-- PART 12: MAINTENANCE AND CLEANUP PROCEDURES
-- ================================================================

-- Function to clean up old history (retention policy)
CREATE OR REPLACE FUNCTION cleanup_old_history(retention_days INTEGER DEFAULT 2555) -- ~7 years
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
    cutoff_date TIMESTAMP WITH TIME ZONE;
BEGIN
    cutoff_date := CURRENT_TIMESTAMP - (retention_days || ' days')::INTERVAL;
    
    DELETE FROM employees_history 
    WHERE sys_end < cutoff_date 
      AND operation_type = 'U'; -- Keep final deletes for audit
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to validate temporal data integrity
CREATE OR REPLACE FUNCTION validate_temporal_integrity()
RETURNS TABLE(
    table_name TEXT,
    issue_type TEXT,
    issue_count BIGINT
) AS $$
BEGIN
    -- Check for overlapping periods in salary_history
    RETURN QUERY
    SELECT 'salary_history'::TEXT, 'overlapping_periods'::TEXT, COUNT(*)
    FROM (
        SELECT s1.employee_uuid
        FROM salary_history s1
        JOIN salary_history s2 ON s1.employee_uuid = s2.employee_uuid 
                               AND s1.salary_id <> s2.salary_id
        WHERE s1.effective_period && s2.effective_period
    ) overlaps;
    
    -- Check for gaps in employee validity
    RETURN QUERY
    SELECT 'employees'::TEXT, 'validity_gaps'::TEXT, COUNT(*)
    FROM employees e
    WHERE e.valid_from > e.hire_date + INTERVAL '1 day';
    
    -- Add more integrity checks as needed
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- PART 13: DEMONSTRATION SCRIPT
-- ================================================================

-- Final demonstration queries for presentation
SELECT '=== TEMPORAL DATA DEMONSTRATION ===' as section;

SELECT 'Current active employees:' as demo_step;
SELECT first_name, last_name, email, salary, hire_date 
FROM current_employees 
ORDER BY hire_date;

SELECT 'Historical changes for John Doe:' as demo_step;
SELECT sys_start, sys_end, salary, operation_type, source_table
FROM all_employee_versions 
WHERE email = 'john.doe@company.com'
ORDER BY sys_start;

SELECT 'Salary progression:' as demo_step;
SELECT * FROM get_salary_timeline('john.doe@company.com');

--SELECT 'Data integrity check:' as demo_step;
--SELECT * FROM validate_temporal_integrity();

-- Show some temporal range queries
SELECT 'Employees valid on 2023-06-01:' as demo_step;
SELECT first_name, last_name, salary
FROM get_employees_at_valid_time('2023-06-01 12:00:00+00')
ORDER BY last_name;

SELECT '=== END DEMONSTRATION ===' as section;

/*
KEY CONCEPTS DEMONSTRATED:

1. BITEMPORAL DATA:
   - System time (when data was recorded in database)
   - Valid time (when data was true in reality)
   - Both can be queried independently

2. TEMPORAL OPERATIONS:
   - INSERT: Creates new temporal records
   - UPDATE: Creates history and new current version
   - DELETE: Logical deletion with history preservation

3. ADVANCED FEATURES:
   - Range types for period management
   - Exclusion constraints prevent overlaps
   - Triggers for automatic history management
   - Functions for temporal queries
   - Views for simplified access

4. PERFORMANCE CONSIDERATIONS:
   - GiST indexes for range queries
   - Proper partitioning strategies
   - History cleanup procedures

5. BUSINESS VALUE:
   - Complete audit trail
   - Point-in-time queries
   - Regulatory compliance
   - Data recovery capabilities
   - Trend analysis

*/
