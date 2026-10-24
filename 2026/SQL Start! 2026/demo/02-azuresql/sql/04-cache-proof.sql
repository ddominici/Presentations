/*  Demo 2 — proof that the second call never reached the database.
    Run before the two REST calls, then again after.  */

SELECT  qs.execution_count,
        qs.last_execution_time,
        SUBSTRING(st.text, 1, 200) AS statement_text
FROM    sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE   st.text LIKE '%dbo.Policies%'
  AND   st.text NOT LIKE '%dm_exec_query_stats%'
ORDER BY qs.last_execution_time DESC;

/*  And, for the "who is connected?" question: DAB puts dab-<version> in the
    connection string's application name, so its sessions are easy to find.  */
SELECT  session_id, login_name, program_name, host_name, status
FROM    sys.dm_exec_sessions
WHERE   program_name LIKE 'dab%';
