/**==============================================================**/
/**  CDB ASSIGNMENT 1 - Motorbike Rental System                  **/
/**  Student Name : Si Yu                                        **/
/**  Student ID   : S10274979K                                   **/
/**  Function     : Returns                                      **/
/**  Object       : uspReturnMotorbike (UPDATE on BikeRental)    **/
/**                                                              **/
/**  Purpose:                                                    **/
/**  Records a motorbike return. Validates the input, works out  **/
/**  extra km, hours late and total cost, then updates the       **/
/**  rental's rent_return_date, rent_extra_km, rent_total_cost.  **/
/**                                                              **/
/**  Team convention (agreed with Reservations):                 **/
/**  BikeRental's return columns are NOT NULL, so a new          **/
/**  reservation is inserted with rent_return_date =             **/
/**  rent_start_date, rent_extra_km = 0, rent_total_cost = 0.    **/
/**  rent_total_cost = 0 therefore means "not yet returned".     **/
/**                                                              **/
/**  Case scenario rules covered:                                **/
/**   - rental must exist and not already be returned            **/
/**   - return date/time must be after the start date/time       **/
/**     and cannot be in the future                              **/
/**   - due = 7:00pm on the last booked day                      **/
/**     (start date + duration - 1), matching the sample data    **/
/**   - 20 free km per booked day; the rest is extra km          **/
/**   - extra km max 255 (rent_extra_km is TINYINT)              **/
/**   - returned after 7:00pm on the due date -> late penalty    **/
/**     per hour (part-hours charged, matching the sample data)  **/
/**   - total cost = days x daily rate + extra km x distance rate**/
/**                  + hours late x late penalty rate            **/
/**                                                              **/
/**  Procedure status values:                                    **/
/**     0   successful return                                    **/
/**   -500  rental ID, return date or km driven not supplied     **/
/**   -501  rental does not exist                                **/
/**   -502  rental already returned                              **/
/**   -503  return date/time not after start date/time           **/
/**   -504  return date/time is in the future                    **/
/**   -505  km driven is negative                                **/
/**   -506  extra km exceeds 255                                 **/
/**   -507  motorbike has no category (rates not found)          **/
/**   -508  error while updating the rental                      **/
/**==============================================================**/

USE MBikeRental
GO

CREATE OR ALTER PROC uspReturnMotorbike
(@rent_id INT,                         -- rental being returned
 @return_date SMALLDATETIME,           -- actual return date and time
 @km_driven INT,                       -- total km driven for the whole rental
 @extra_km INT OUTPUT,                 -- km charged above the free allowance
 @hours_late DECIMAL(8,2) OUTPUT,      -- hours after 7pm on the due date
 @total_cost SMALLMONEY OUTPUT)        -- final amount the member pays
AS

DECLARE @start_date SMALLDATETIME, @duration TINYINT, @recorded_cost SMALLMONEY,
        @bike_id CHAR(5), @cat_id CHAR(2),
        @rental_rate SMALLMONEY, @distance_rate SMALLMONEY, @penalty_rate SMALLMONEY,
        @free_km INT, @due_date SMALLDATETIME

-- Start the output parameters at 0 so the caller never receives NULL
SET @extra_km = 0
SET @hours_late = 0
SET @total_cost = 0

/** Check 1: Rental ID, return date and km driven must all be supplied **/
IF @rent_id IS NULL OR @return_date IS NULL OR @km_driven IS NULL
BEGIN
    PRINT 'Error: Rental ID, return date/time and km driven are all required.'
    RETURN -500
END

/** Check 2: The rental must exist **/
IF NOT EXISTS (SELECT rent_id FROM BikeRental WHERE rent_id = @rent_id)
BEGIN
    PRINT 'Error: Rental ID ' + CAST(@rent_id AS VARCHAR(10)) + ' does not exist.'
    RETURN -501
END

-- Get the rental details needed for the remaining checks and the cost
SELECT @start_date = rent_start_date, @duration = rent_duration,
       @recorded_cost = rent_total_cost, @bike_id = rent_bikeid
FROM BikeRental
WHERE rent_id = @rent_id

/** Check 3: The rental must not already be returned (cost 0 = not returned) **/
IF @recorded_cost <> 0
BEGIN
    PRINT 'Error: Rental ID ' + CAST(@rent_id AS VARCHAR(10))
        + ' has already been returned (total cost $'
        + CAST(@recorded_cost AS VARCHAR(12)) + ').'
    RETURN -502
END

/** Check 4: Return date/time must be after the start date/time **/
IF @return_date <= @start_date
BEGIN
    PRINT 'Error: Return date/time (' + CAST(@return_date AS VARCHAR(20))
        + ') must be after the start date/time ('
        + CAST(@start_date AS VARCHAR(20)) + ').'
    RETURN -503
END

/** Check 5: Return date/time cannot be in the future **/
IF @return_date > GETDATE()
BEGIN
    PRINT 'Error: Return date/time (' + CAST(@return_date AS VARCHAR(20))
        + ') cannot be in the future.'
    RETURN -504
END

/** Check 6: Km driven cannot be negative **/
IF @km_driven < 0
BEGIN
    PRINT 'Error: Km driven cannot be negative.'
    RETURN -505
END

-- Each booked day gets 20 free km; anything above that is extra km
SET @free_km = @duration * 20
SET @extra_km = @km_driven - @free_km
IF @extra_km < 0
    SET @extra_km = 0

/** Check 7: Extra km must fit in rent_extra_km (TINYINT, max 255) **/
IF @extra_km > 255
BEGIN
    PRINT 'Error: Extra km (' + CAST(@extra_km AS VARCHAR(10))
        + ') exceeds the maximum of 255. Free allowance is '
        + CAST(@free_km AS VARCHAR(10)) + ' km for '
        + CAST(@duration AS VARCHAR(3)) + ' day(s).'
    SET @extra_km = 0
    RETURN -506
END

-- Get the rates of the motorbike's category
SELECT @cat_id = c.cat_id, @rental_rate = c.cat_rental_rate,
       @distance_rate = c.cat_distance_rate, @penalty_rate = c.cat_late_penalty_rate
FROM Motorbike m
INNER JOIN BikeCategory c ON m.bike_category = c.cat_id
WHERE m.bike_id = @bike_id

/** Check 8: The motorbike must belong to a category so the rates can be found **/
IF @cat_id IS NULL
BEGIN
    PRINT 'Error: Motorbike ' + @bike_id + ' has no category, so its rates cannot be found.'
    SET @extra_km = 0
    RETURN -507
END

-- Due date = 7:00pm on the last booked day
SET @due_date = CAST(@start_date AS DATE)            -- midnight of the start day
SET @due_date = DATEADD(DAY, @duration - 1, @due_date) -- move to the last booked day
SET @due_date = DATEADD(HOUR, 19, @due_date)         -- 7:00pm on that day

-- Hours late: only counted if returned after the due time (part-hours included)
IF @return_date > @due_date
    SET @hours_late = DATEDIFF(MINUTE, @due_date, @return_date) / 60.0

-- Total cost = days x daily rate + extra km x distance rate + hours late x late penalty rate
SET @total_cost = (@duration * @rental_rate)
                + (@extra_km * @distance_rate)
                + (@hours_late * @penalty_rate)

-- Record the return
UPDATE BikeRental
SET rent_return_date = @return_date,
    rent_extra_km = @extra_km,
    rent_total_cost = @total_cost
WHERE rent_id = @rent_id

/** Check 9: The update must not cause an error **/
IF @@ERROR <> 0
BEGIN
    PRINT 'Error: Return for rental ID ' + CAST(@rent_id AS VARCHAR(10)) + ' could not be recorded.'
    SET @extra_km = 0
    SET @hours_late = 0
    SET @total_cost = 0
    RETURN -508
END

PRINT 'Rental ID ' + CAST(@rent_id AS VARCHAR(10)) + ' returned successfully.'
PRINT '  Due       : ' + CAST(@due_date AS VARCHAR(20))
PRINT '  Returned  : ' + CAST(@return_date AS VARCHAR(20))
PRINT '  Extra km  : ' + CAST(@extra_km AS VARCHAR(10))
PRINT '  Hours late: ' + CAST(@hours_late AS VARCHAR(10))
PRINT '  Total cost: $' + CAST(@total_cost AS VARCHAR(12))
RETURN 0
GO


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