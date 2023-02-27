USE master
GO

SELECT
	er.session_id
	, er.wait_type	
	, er.wait_resource
	, OBJECT_NAME(i.[object_id], i.database_id) AS [object_name]
	, er.blocking_session_id
	, er.command
	, SUBSTRING(st.text, 
		(er.statement_start_offset/2)+1,
		((	CASE er.statement_end_offset 
				WHEN -1 THEN DATALENGTH(st.text)
				ELSE er.statement_end_offset
			END - er.statement_start_offset)/2)+1) AS statement_text
	, i.database_id
	, i.file_id
	, i.page_id
	, i.object_id
	, i.index_id
	, i.page_type_desc
FROM sys.dm_exec_requests AS er
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
CROSS APPLY sys.fn_PageResCracker(er.page_resource) AS rc
CROSS APPLY sys.dm_db_page_info(rc.[db_id], rc.[file_id], rc.page_id, 'DETAILED') AS i
WHERE er.wait_type LIKE '%page%'
