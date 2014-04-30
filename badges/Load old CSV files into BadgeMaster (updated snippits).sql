-- mark all existing badges as inactive
UPDATE Badges
SET IsActive = 'FALSE'

-- reactivate badges in Badges that were active in CSV
UPDATE Badges
Set IsActive = 'TRUE'
From Badges INNER JOIN CVStaging on Badges.RFID = CVStaging.RFID

-- any active badges with a date in DateDropped must have been reactivated, so
-- change DateDropped to null and DateAdded to @FileDate
UPDATE Badges
Set DateDropped = null
    ,DateAdded = @FileDate
FROM Badges INNER JOIN CVStaging on Badges.RFID = CVStaging.RFID
WHERE DateDropped is not null
    and IsActive = 'TRUE'
    
-- if a badge isn't in the current CSVStaging table, it is inactive.  If DateDropped
-- is null, change it to @FileDate
UPDATE Badges
SET DateDropped = @FileDate
    ,DuplicateReason = 'Dropped on ' + @FileDate
WHERE DateDropped is null
    and RFID NOT IN (SELECT RFID FROM CSVStaging)