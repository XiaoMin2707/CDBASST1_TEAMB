/**==============================================================**/
/**  TEST CALLS - uspReturnMotorbike (Si Yu)                     **/
/**  Run everything below in one go so the variables carry over. **/
/**==============================================================**/

DECLARE @Status INT, @ExtraKm INT, @HoursLate DECIMAL(8,2), @TotalCost SMALLMONEY,
        @TestRentID INT, @NoCatRentID INT

-- Test data 1: unreturned 2-day rental on B0008 (C1: $50/day, $0.20/km, $5/hr late)
-- Placeholders: return date = start date, extra km = 0, total cost = 0
INSERT INTO BikeRental (rent_start_date, rent_duration, rent_return_date,
                        rent_extra_km, rent_total_cost, rent_memberid, rent_bikeid)
VALUES ('2026/11/19 9:00 AM', 2, '2026/11/19 9:00 AM', 0, 0, 'M00002', 'B0008')
SET @TestRentID = SCOPE_IDENTITY()

-- Test data 2: a motorbike with no category, and an unreturned rental on it (for Test 8)
INSERT INTO Motorbike (bike_id, bike_plate_number, bike_brand, bike_model,
                       bike_engine_cc, bike_status, bike_category, bike_station)
VALUES ('B0099', 'FZZ9999Z', 'Test', 'No Category', 100, 'Available', NULL, 'S01')

INSERT INTO BikeRental (rent_start_date, rent_duration, rent_return_date,
                        rent_extra_km, rent_total_cost, rent_memberid, rent_bikeid)
VALUES ('2026/11/19 9:00 AM', 1, '2026/11/19 9:00 AM', 0, 0, 'M00002', 'B0099')
SET @NoCatRentID = SCOPE_IDENTITY()

PRINT '--- Test 1 (fail, -500): rental ID not supplied ---'
EXEC @Status = uspReturnMotorbike NULL, '2026/11/20 8:30 PM', 70,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 2 (fail, -501): rental does not exist ---'
EXEC @Status = uspReturnMotorbike 9999, '2026/11/20 8:30 PM', 70,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 3 (fail, -502): rental 1 is already returned ---'
EXEC @Status = uspReturnMotorbike 1, '2026/11/20 8:30 PM', 70,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 4 (fail, -503: return before the start time ---'
EXEC @Status = uspReturnMotorbike @TestRentID, '2026/11/19 8:00 AM', 70,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 5 (fail, -504): return date in the future ---'
EXEC @Status = uspReturnMotorbike @TestRentID, '2030/01/01 10:00 AM', 70,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 6 (fail, -505): negative km ---'
EXEC @Status = uspReturnMotorbike @TestRentID, '2026/11/20 8:30 PM', -5,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 7 (fail, -506): extra km over 255 (40 free + 256 extra) ---'
EXEC @Status = uspReturnMotorbike @TestRentID, '2026/11/20 8:30 PM', 296,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 8 (fail, -507): motorbike has no category ---'
EXEC @Status = uspReturnMotorbike @NoCatRentID, '2026/11/20 8:30 PM', 10,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

PRINT '--- Test 9 (VALID, 0): 70 km, returned 8:30pm on the due date ---'
PRINT '    Expected: 2 x $50 + 30 km x $0.20 + 1.5 hrs x $5 = $113.50'
EXEC @Status = uspReturnMotorbike @rent_id = @TestRentID,
     @return_date = '2026/11/20 8:30 PM', @km_driven = 70,
     @extra_km = @ExtraKm OUTPUT, @hours_late = @HoursLate OUTPUT,
     @total_cost = @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))
SELECT 'Status' = @Status, 'Extra Km' = @ExtraKm,
       'Hours Late' = @HoursLate, 'Total Cost' = @TotalCost

PRINT '--- Test 10 (fail, -502): returning the same rental twice ---'
EXEC @Status = uspReturnMotorbike @TestRentID, '2026/11/20 8:30 PM', 70,
     @ExtraKm OUTPUT, @HoursLate OUTPUT, @TotalCost OUTPUT
PRINT 'Status: ' + CAST(@Status AS VARCHAR(5))

-- Show the updated rental
SELECT rent_id, rent_start_date, rent_duration, rent_return_date,
       rent_extra_km, rent_total_cost, rent_memberid, rent_bikeid
FROM BikeRental
WHERE rent_id = @TestRentID

-- Remove the no-category test data so it does not affect other members' work
DELETE FROM BikeRental WHERE rent_id = @NoCatRentID
DELETE FROM Motorbike WHERE bike_id = 'B0099'
GO