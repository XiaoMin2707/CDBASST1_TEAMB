/**==============================================================**/
/**  CDB ASSIGNMENT 1 – Motorbike Rental System                  **/
/**  Student Name : Si Yu                                        **/
/**  Student ID   : S10274979                                    **/
/**  Function     : Returns                                      **/
/**  Object       : uspReturnMotorbike (UPDATE on BikeRental)    **/
/**                                                              **/
/**  Purpose:                                                    **/
/**  Records a motorbike return. Validates the input, works out  **/
/**  extra km, hours late and total cost, then updates the       **/
/**  rental's rent_return_date, rent_extra_km and rent_total_cost.**/
/**                                                              **/
/**  Team convention    **/
/**  BikeRental's return columns are NOT NULL, so a new reservation is inserted with **/  
/**  rent_return_date = rent_start_date, rent_extra_km = 0, rent_total_cost = 0.    **/
/**  rent_total_cost = 0 therefore means "not yet returned"      **/
/**  (a real rental can never cost $0: duration >= 1, rate > 0). **/
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
/**     per hour (part-hours prorated, matching the sample data) **/
/**   - total cost = days x daily rate + extra km x distance rate + hours late x late penalty rate            **/
/**                                                              **/
/**  Return codes:                                               **/
/**   0 = success                                                **/
/**   1 = missing input            6 = negative km driven        **/
/**   2 = rental not found         7 = extra km exceeds 255      **/
/**   3 = already returned         8 = bike has no category      **/
/**   4 = return before start      9 = update failed             **/
/**   5 = return in the future                                   **/
/**==============================================================**/

USE MBikeRental
GO

IF OBJECT_ID('uspReturnMotorbike', 'P') IS NOT NULL
    DROP PROCEDURE uspReturnMotorbike
GO

CREATE PROCEDURE uspReturnMotorbike
    @rent_id      INT,                       -- rental being returned
    @return_date  SMALLDATETIME,             -- actual return date and time
    @km_driven    INT,                       -- total km driven for the whole rental
    @extra_km     INT           OUTPUT,      -- km charged above the free allowance
    @hours_late   DECIMAL(8,2)  OUTPUT,      -- hours after 7pm on the due date
    @total_cost   SMALLMONEY    OUTPUT       -- final amount the member pays
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @start_date     SMALLDATETIME,
            @duration       TINYINT,
            @recorded_cost  SMALLMONEY,
            @bike_id        CHAR(5),
            @cat_id         CHAR(2),
            @rental_rate    SMALLMONEY,
            @distance_rate  SMALLMONEY,
            @penalty_rate   SMALLMONEY,
            @free_km        INT,
            @due_date       SMALLDATETIME

    -- Default the output parameters so the caller never gets NULLs
    SET @extra_km   = 0
    SET @hours_late = 0
    SET @total_cost = 0

    /** Check 1: All required inputs must be supplied **/
    IF @rent_id IS NULL OR @return_date IS NULL OR @km_driven IS NULL
    BEGIN
        PRINT 'Error: Rental ID, return date/time and km driven are all required.'
        RETURN 1
    END

    /** Check 2: The rental must exist **/
    SELECT @start_date    = rent_start_date,
           @duration      = rent_duration,
           @recorded_cost = rent_total_cost,
           @bike_id       = rent_bikeid
    FROM   BikeRental
    WHERE  rent_id = @rent_id

    IF @start_date IS NULL
    BEGIN
        PRINT 'Error: Rental ID ' + CAST(@rent_id AS VARCHAR(10)) + ' does not exist.'
        RETURN 2
    END

    /** Check 3: The rental must not already be returned (cost 0 = not returned) **/
    IF @recorded_cost <> 0
    BEGIN
        PRINT 'Error: Rental ID ' + CAST(@rent_id AS VARCHAR(10))
            + ' has already been returned (total cost $'
            + CAST(@recorded_cost AS VARCHAR(12)) + ').'
        RETURN 3
    END

    /** Check 4: Return date/time must be after the start date/time **/
    IF @return_date <= @start_date
    BEGIN
        PRINT 'Error: Return date/time (' + CONVERT(VARCHAR(20), @return_date, 120)
            + ') must be after the start date/time ('
            + CONVERT(VARCHAR(20), @start_date, 120) + ').'
        RETURN 4
    END

    /** Check 5: Return date/time cannot be in the future **/
    IF @return_date > GETDATE()
    BEGIN
        PRINT 'Error: Return date/time (' + CONVERT(VARCHAR(20), @return_date, 120)
            + ') cannot be in the future.'
        RETURN 5
    END

    /** Check 6: Km driven cannot be negative **/
    IF @km_driven < 0
    BEGIN
        PRINT 'Error: Km driven cannot be negative.'
        RETURN 6
    END

    /** Calculate extra km: each booked day gets 20 free km **/
    SET @free_km  = @duration * 20
    SET @extra_km = CASE WHEN @km_driven > @free_km
                         THEN @km_driven - @free_km
                         ELSE 0 END

    /** Check 7: Extra km must fit rent_extra_km (TINYINT, max 255) **/
    IF @extra_km > 255
    BEGIN
        PRINT 'Error: Extra km (' + CAST(@extra_km AS VARCHAR(10))
            + ') exceeds the maximum of 255. Free allowance is '
            + CAST(@free_km AS VARCHAR(10)) + ' km for '
            + CAST(@duration AS VARCHAR(3)) + ' day(s).'
        SET @extra_km = 0
        RETURN 7
    END

    /** Check 8: The bike must belong to a category so the rates can be found **/
    SELECT @cat_id        = c.cat_id,
           @rental_rate   = c.cat_rental_rate,
           @distance_rate = c.cat_distance_rate,
           @penalty_rate  = c.cat_late_penalty_rate
    FROM   Motorbike m
           JOIN BikeCategory c ON m.bike_category = c.cat_id
    WHERE  m.bike_id = @bike_id

    IF @cat_id IS NULL
    BEGIN
        PRINT 'Error: Motorbike ' + @bike_id
            + ' has no category, so its rates cannot be found.'
        SET @extra_km = 0
        RETURN 8
    END

    /** Due = 7:00pm on the last booked day (start date + duration - 1) **/
    SET @due_date = DATEADD(HOUR, 19,
                        CAST(CAST(DATEADD(DAY, @duration - 1, @start_date) AS DATE)
                             AS SMALLDATETIME))

    /** Hours late: only if returned after the due time; part-hours prorated **/
    SET @hours_late = CASE WHEN @return_date > @due_date
                           THEN DATEDIFF(MINUTE, @due_date, @return_date) / 60.0
                           ELSE 0 END

    /** Total cost = days x daily rate + extra km x distance rate
                    + hours late x late penalty rate **/
    SET @total_cost = (@duration   * @rental_rate)
                    + (@extra_km   * @distance_rate)
                    + (@hours_late * @penalty_rate)

    /** Record the return. The rent_total_cost = 0 condition stops a
        double return if two people run this at the same time. **/
    UPDATE BikeRental
    SET    rent_return_date = @return_date,
           rent_extra_km    = @extra_km,
           rent_total_cost  = @total_cost
    WHERE  rent_id = @rent_id
      AND  rent_total_cost = 0

    /** Check 9: The update must succeed and touch exactly one row **/
    IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
    BEGIN
        PRINT 'Error: Return for rental ID ' + CAST(@rent_id AS VARCHAR(10))
            + ' could not be recorded.'
        SET @extra_km = 0; SET @hours_late = 0; SET @total_cost = 0
        RETURN 9
    END

    PRINT 'Rental ID ' + CAST(@rent_id AS VARCHAR(10)) + ' returned successfully.'
    PRINT '  Due       : ' + CONVERT(VARCHAR(20), @due_date, 120)
    PRINT '  Returned  : ' + CONVERT(VARCHAR(20), @return_date, 120)
    PRINT '  Extra km  : ' + CAST(@extra_km AS VARCHAR(10))
    PRINT '  Hours late: ' + CAST(@hours_late AS VARCHAR(10))
    PRINT '  Total cost: $' + CAST(@total_cost AS VARCHAR(12))
    RETURN 0
END
GO


/**==============================================================**/
/**  TEST CALLS – uspReturnMotorbike (Si Yu)                     **/
/**  All in one batch so the variables carry through.            **/
/**  Dates are relative to today so the tests work on any run    **/
/**  date.                                                       **/
/**==============================================================**/

DECLARE @rc INT, @xkm INT, @late DECIMAL(8,2), @cost SMALLMONEY
DECLARE @testRent INT, @noCatRent INT
DECLARE @start SMALLDATETIME, @goodReturn SMALLDATETIME, @future SMALLDATETIME

-- Test rental: started 3 days ago at 9:00am, 2 days, bike B0008 (C1), member M00002 (2B)
SET @start      = DATEADD(HOUR, 9, CAST(CAST(DATEADD(DAY, -3, GETDATE()) AS DATE) AS SMALLDATETIME))
SET @goodReturn = DATEADD(MINUTE, 30, DATEADD(HOUR, 11, DATEADD(DAY, 1, @start)))   -- day 2, 8:30pm (1.5 hrs late)
SET @future     = DATEADD(DAY, 7, GETDATE())

-- Unreturned reservation (team convention: return date = start, extra km 0, cost 0)
INSERT INTO BikeRental VALUES (@start, 2, @start, 0, 0, 'M00002', 'B0008')
SET @testRent = SCOPE_IDENTITY()

-- Test bike with no category, plus an unreturned rental on it (for Check 8)
INSERT INTO Motorbike VALUES ('B0099', 'FZZ9999Z', 'Test', 'No Category', 100, 'Available', NULL, 'S01')
INSERT INTO BikeRental VALUES (@start, 1, @start, 0, 0, 'M00002', 'B0099')
SET @noCatRent = SCOPE_IDENTITY()

PRINT '--- Test 1 (fail, code 1): missing input ---'
EXEC @rc = uspReturnMotorbike NULL, @goodReturn, 70, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 2 (fail, code 2): rental does not exist ---'
EXEC @rc = uspReturnMotorbike 9999, @goodReturn, 70, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 3 (fail, code 3): rental 1 is already returned ---'
EXEC @rc = uspReturnMotorbike 1, @goodReturn, 70, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 4 (fail, code 4): return before start ---'
DECLARE @beforeStart SMALLDATETIME = DATEADD(HOUR, -1, @start)
EXEC @rc = uspReturnMotorbike @testRent, @beforeStart, 70, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 5 (fail, code 5): return in the future ---'
EXEC @rc = uspReturnMotorbike @testRent, @future, 70, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 6 (fail, code 6): negative km ---'
EXEC @rc = uspReturnMotorbike @testRent, @goodReturn, -5, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 7 (fail, code 7): extra km over 255 (40 free + 256 extra) ---'
EXEC @rc = uspReturnMotorbike @testRent, @goodReturn, 296, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 8 (fail, code 8): bike has no category ---'
EXEC @rc = uspReturnMotorbike @noCatRent, @goodReturn, 10, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

PRINT '--- Test 9 (VALID, code 0): 70 km, 1.5 hrs late on a C1 bike ---'
PRINT '    Expected: 2 x 50 + 30 x 0.20 + 1.5 x 5 = $113.50'
EXEC @rc = uspReturnMotorbike @testRent, @goodReturn, 70, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))
SELECT @rc AS ReturnCode, @xkm AS ExtraKm, @late AS HoursLate, @cost AS TotalCost

PRINT '--- Test 10 (fail, code 3): returning the same rental twice ---'
EXEC @rc = uspReturnMotorbike @testRent, @goodReturn, 70, @xkm OUTPUT, @late OUTPUT, @cost OUTPUT
PRINT 'Return code: ' + CAST(@rc AS VARCHAR(3))

-- Show the updated row
SELECT * FROM BikeRental WHERE rent_id = @testRent

-- Clean up the no-category test bike so it doesn't clash with Fleet validation
DELETE FROM BikeRental WHERE rent_id = @noCatRent
DELETE FROM Motorbike  WHERE bike_id = 'B0099'
GO