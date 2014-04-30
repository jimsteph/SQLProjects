-- mark all existing badges as inactive
UPDATE Badges
SET IsActive = 'FALSE'

-- reactivate badges in Badges that were active in CSV
UPDATE Badges
Set IsActive = 'TRUE'

From Badges INNER JOIN CVStaging on Badges.RFID = CVStaging.RFID