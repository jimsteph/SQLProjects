-- In the OldCSV directory, delete all 'allfile' files.  Then run the following command
-- at the command line from within the OldCSV directory:
--     dir /B /O:D >allfile.txt
-- This will create a file called allfile.txt with all file names listed in date-
-- attribute order (ascending).
-- Load old CSV files into Pinnacle
SET NOCOUNT ON

USE ScratchPad;

DECLARE @Path VARCHAR(500) = 'C:\PSBadges\OldCSV\';
DECLARE @FileName VARCHAR(100);
DECLARE @FileDate DATE;
DECLARE @sql VARCHAR(8000)

-- start by copying all old filenames into temporary table
CREATE TABLE #files (NAME VARCHAR(200));

BULK INSERT #files
FROM 'c:\PSBadges\OldCSV\allfile.txt' WITH (
		FIELDTERMINATOR = ','
		,ROWTERMINATOR = '\n'
		);

-- get rid of spreadsheets: we only want the actual csv files
DELETE
FROM #files
WHERE NAME LIKE '%xlsx';

-- clear out any existing data from Badges
TRUNCATE TABLE Badges

-- And so it begins ...
DECLARE FileCursor CURSOR LOCAL FAST_FORWARD
FOR
SELECT NAME
FROM #files;

OPEN FileCursor;

FETCH NEXT
FROM FileCursor
INTO @FileName;

WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT 'Processing ' + @Path + @FileName;

	-- we care about the date the file was supposedly created on, not the actual
	-- timestamp date
	SET @FileDate = CAST(SUBSTRING(@FileName, 16, 10) AS DATE);

	PRINT '  Current date: ' + ISNULL(CONVERT(VARCHAR(20), @FileDate), '');

	-- dynamic sql for bulk insert
	SET @sql = 'BULK INSERT CSVStaging 
	FROM ''' + @Path + @FileName + ''' 
	WITH 
		(FIELDTERMINATOR = '','',
		 ROWTERMINATOR = ''\n''
	);';

	-- clear out staging table first
	TRUNCATE TABLE CSVStaging;

	-- bulk load the current file, ignoring the error caused by the header line in each csv
	BEGIN TRY
		EXEC (@sql);
	END TRY

	BEGIN CATCH
		PRINT '***error processing the header***'
	END CATCH;

	PRINT '     Import: Done';

	-- If the StudentID is more than seven characters, it's a duplicate card
	DELETE
	FROM CSVStaging
	WHERE NOT (
			(LEN(StudentID) = 7)
			AND (StudentID NOT LIKE '%Bus%')
			);

	/*  Here is where we'll process the csv files we just loaded */
	-- start by marking all existing badges as inactive
	UPDATE Badges
	SET IsActive = 'FALSE'

	-- copy all badges that are new into the database	
	INSERT INTO Badges (
		RFID
		,StudentID
		,Duplicates
		,DateIssued
		,DateDeactivated
		,DuplicateReason
		,DuplicateNumber
		,IsActive
		)
	SELECT C.RFID
		,left(C.StudentID, 7)
		,'False'
		,@FileDate
		,NULL
		,'New Badge'
		,0
		,'TRUE'
	FROM CSVStaging AS C
	WHERE C.RFID NOT IN (
			SELECT RFID
			FROM Badges
			);

	-- reactivate badges in Badges that were active in CSV
	UPDATE Badges
	SET IsActive = 'TRUE'
	FROM Badges
	INNER JOIN CSVStaging ON Badges.RFID = CSVStaging.RFID

	-- any active badges with a date in DateDeactivated must have just been reactivated, so
	-- change DateDeactivated to null and DateAdded to @FileDate
	UPDATE Badges
	SET DateDeactivated = NULL
		,DateIssued = @FileDate
	FROM Badges
	INNER JOIN CSVStaging ON Badges.RFID = CSVStaging.RFID
	WHERE DateDeactivated IS NOT NULL
		AND IsActive = 'TRUE'

	-- if a badge isn't in the current CSVStaging table, it is inactive.  If DateDeactivated
	-- is null, it just went inactive so change it to @FileDate
	UPDATE Badges
	SET DateDeactivated = @FileDate
		,DuplicateReason = 'Dropped on ' + convert(varchar(30),@FileDate)
	WHERE DateDeactivated IS NULL
		AND RFID NOT IN (
			SELECT RFID
			FROM CSVStaging
			)

	FETCH NEXT
	FROM FileCursor
	INTO @FileName
END;

CLOSE FileCursor;

DEALLOCATE FileCursor;

SELECT SS.LastName
	,SS.FirstName
	,SS.StudentID
	,SS.School
	,B.IsActive
	,B.RFID
	,B.StudentID
	,B.Duplicates
	,B.DateIssued
	,B.DateDeactivated
	,B.DuplicateReason
	,B.DuplicateNumber
FROM Badges AS B
LEFT JOIN Students AS SS ON B.StudentID = SS.StudentID
--	where ss.LastName is null order by b.DateIssued
ORDER BY ss.LastName
	,ss.FirstName
	,ss.StudentID
	,b.RFID

DROP TABLE #files
	--	select * from Badges where IsActive = 1