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


/** TEST CALLS - uspUpdateBikeStatus **/
BEGIN TRAN
DECLARE @Status INT, @TestBike CHAR(5), @TestBike2 CHAR(5)

-- Pick two available bikes with no unreturned rentals
SELECT TOP 1 @TestBike = bike_id FROM Motorbike
WHERE bike_status = 'Available'
  AND bike_id NOT IN (SELECT rent_bikeid FROM BikeRental WHERE rent_total_cost = 0)
ORDER BY bike_id

SELECT TOP 1 @TestBike2 = bike_id FROM Motorbike
WHERE bike_status = 'Available' AND bike_id <> @TestBike
  AND bike_id NOT IN (SELECT rent_bikeid FROM BikeRental WHERE rent_total_cost = 0)
ORDER BY bike_id

EXEC @Status = uspUpdateBikeStatus NULL, 'Maintenance'
SELECT 'Test 1 (-701 missing info)' AS Test, @Status AS Status

EXEC @Status = uspUpdateBikeStatus 'B9999', 'Maintenance'
SELECT 'Test 2 (-702 bike does not exist)' AS Test, @Status AS Status

EXEC @Status = uspUpdateBikeStatus @TestBike, 'Broken'
SELECT 'Test 3 (-703 invalid status)' AS Test, @Status AS Status

EXEC @Status = uspUpdateBikeStatus @TestBike, 'Available'
SELECT 'Test 4 (-704 same status)' AS Test, @Status AS Status

-- Give @TestBike an unreturned rental (placeholders as per team convention)
INSERT INTO BikeRental (rent_start_date, rent_duration, rent_return_date,
                        rent_extra_km, rent_total_cost, rent_memberid, rent_bikeid)
VALUES ('20261120 09:00', 2, '20261120 09:00', 0, 0, 'M00002', @TestBike)

EXEC @Status = uspUpdateBikeStatus @TestBike, 'Maintenance'
SELECT 'Test 5 (-705 unreturned rental)' AS Test, @Status AS Status

EXEC @Status = uspUpdateBikeStatus @TestBike, 'Rented'
SELECT 'Test 6 (0 valid: Available -> Rented)' AS Test, @Status AS Status

EXEC @Status = uspUpdateBikeStatus @TestBike2, 'Retired'
SELECT 'Test 7 (0 valid: Available -> Retired)' AS Test, @Status AS Status

EXEC @Status = uspUpdateBikeStatus @TestBike2, 'Available'
SELECT 'Test 8 (-706 retired bike)' AS Test, @Status AS Status

SELECT bike_id, bike_status FROM Motorbike WHERE bike_id IN (@TestBike, @TestBike2)

ROLLBACK
GO
