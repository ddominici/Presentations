ECHO OFF
rd /s /q %temp%\output
"ostress.exe" -E -dAdventureWorks2019 -Q"EXEC dbo.usp_EmployeeBirthdayList 4"  -mstress -quiet -n1 -r1 | FINDSTR "Cantfindthisstring"
rd /s /q %temp%\output
"ostress.exe" -E -dAdventureWorks2019 -Q"EXEC dbo.usp_EmployeeBirthdayList 4"  -mstress -quiet -n100 -r300 | FINDSTR "QEXEC Starting Creating elapsed"