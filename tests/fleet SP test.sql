/** TEST CALLS - uspAddMotorbike **/
BEGIN TRAN
DECLARE @Status INT, @ExistingPlate VARCHAR(8)
SELECT TOP 1 @ExistingPlate = bike_plate_number FROM Motorbike

EXEC @Status = uspAddMotorbike NULL, 'FBA1234A', 'Honda', 'Test', 150, 'C1', 'S01'
SELECT 'Test 1 (-601 missing info)' AS Test, @Status AS Status

EXEC @Status = uspAddMotorbike 'B0008', 'FBA1234A', 'Honda', 'Test', 150, 'C1', 'S01'
SELECT 'Test 2 (-602 duplicate bike ID)' AS Test, @Status AS Status

EXEC @Status = uspAddMotorbike 'B0050', @ExistingPlate, 'Honda', 'Test', 150, 'C1', 'S01'
SELECT 'Test 3 (-603 duplicate plate)' AS Test, @Status AS Status

EXEC @Status = uspAddMotorbike 'B0050', 'FBA1234A', 'Honda', 'Test', 150, 'ZZ', 'S01'
SELECT 'Test 4 (-604 no category)' AS Test, @Status AS Status

EXEC @Status = uspAddMotorbike 'B0050', 'FBA1234A', 'Honda', 'Test', 150, 'C1', 'ZZZ'
SELECT 'Test 5 (-605 no station)' AS Test, @Status AS Status

EXEC @Status = uspAddMotorbike 'B0050', 'FBA1234A', 'Honda', 'Test', 0, 'C1', 'S01'
SELECT 'Test 6 (-606 invalid cc)' AS Test, @Status AS Status

EXEC @Status = uspAddMotorbike 'B0050', 'FBA1234A', 'Honda', 'Test', 650, 'C1', 'S01'
SELECT 'Test 7 (-607 cc vs licence)' AS Test, @Status AS Status

EXEC @Status = uspAddMotorbike 'B0050', 'FBA1234A', 'Honda', 'Test', 150, 'C1', 'S01'
SELECT 'Test 8 (0 valid)' AS Test, @Status AS Status
SELECT * FROM Motorbike WHERE bike_id = 'B0050'

ROLLBACK
GO
