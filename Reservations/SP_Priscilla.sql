CREATE PROC uspCreateReservation (@MemberID CHAR(6) = NULL, @BikeCatID CHAR(2) = NULL , @StationID CHAR(3) = NULL, @StartDateTime SMALLDATETIME = NULL, @RentDurationDays TINYINT = NULL)
AS
	DECLARE @MemberAge INTEGER, @MemberLicenceClass VARCHAR(2), @AssignedBike CHAR(5), @MemberStatus VARCHAR(15), @CatLicenceClass VARCHAR(2)

	IF @BikeCatID IS NULL
		RETURN -400 -- Bike catgory ID cannot be null
	IF @StationID IS NULL
		RETURN -401 -- Station ID cannot be null
	IF @StartDateTime IS NULL
		RETURN -402 -- Start date and time cannot be null
	IF @RentDurationDays IS NULL
		RETURN -403 -- Rent duration in days cannot be null

	IF NOT EXISTS (SELECT * FROM Member WHERE mem_id = @MemberID)
		RETURN -404 -- Member does not exist
	IF NOT EXISTS (SELECT * FROM BikeCategory WHERE cat_id = @BikeCatID)
		RETURN -405 -- Bike category does not exist
	IF NOT EXISTS (SELECT * FROM BikeStation WHERE stat_id = @StationID)
		RETURN -406 -- Bike station does not exist
	

	SELECT @MemberStatus = mem_status
	FROM Member
	WHERE mem_id = @MemberID

	IF @MemberStatus = 'Active'
	BEGIN
		SELECT @MemberAge =
			DATEDIFF(YEAR, mem_dob, GETDATE())
			- CASE
				WHEN DATEADD(YEAR,
					DATEDIFF(YEAR, mem_dob, GETDATE()),
					mem_dob) > GETDATE()
				THEN 1
				ELSE 0
			  END
		FROM Member
		WHERE mem_id = @MemberID;
		IF @MemberAge >= 22 AND @MemberAge <= 65
		BEGIN
			SELECT @MemberLicenceClass = mem_licence_class
			FROM Member
			WHERE mem_id = @MemberID

			SELECT @CatLicenceClass = c.cat_licence_class
			FROM BikeCategory c INNER JOIN Motorbike b
			ON c.cat_id = b.bike_category

			IF @MemberLicenceClass = @CatLicenceClass
				IF @StartDateTime >= GETDATE()
				BEGIN
					SELECT TOP 1 @AssignedBike = b.bike_id
					FROM Motorbike b INNER JOIN BikeCategory c
					ON b.bike_category = c.cat_id
					WHERE b.bike_status = 'Available' AND c.cat_licence_class = @MemberLicenceClass AND b.bike_category = @BikeCatID AND b.bike_station = @StationID
					IF @AssignedBike IS NULL
						RETURN -411 -- No available bike found
					ELSE
					BEGIN
						
						UPDATE Motorbike
						SET bike_status = 'Not Available'
						WHERE bike_id = @AssignedBike
						
						INSERT INTO BikeRental (rent_start_date, rent_duration, rent_return_date, rent_extra_km, rent_total_cost, rent_memberid, rent_bikeid)
						VALUES (@StartDateTime, @RentDurationDays, '2079-06-06', 0, 0, @MemberID, @AssignedBike)

						IF @@ERROR <> 0
							RETURN -412 -- Update or insert statement failed
					END
				END
				ELSE
					RETURN -410 -- Start date and time cannot be before today's date
			ELSE
				RETURN -409 -- Bike category and license mismatch

		END
		ELSE
			RETURN -408 -- Member's age is not between 22 to 65 years old, hence not eligible to rent a bike
	END		
	ELSE
		RETURN -407 -- Member status is not active

RETURN
GO

--DROP PROC uspCreateReservation

-- Case 1: Successful booking
DECLARE @Status INT
EXEC @Status = uspCreateReservation 'M00002', 'C1', 'S01', '2026-12-22 07:00', 5
SELECT @Status

-- Case 2: Bike cateogry does not exist
DECLARE @Status INT
EXEC @Status = uspCreateReservation
    'M00002', 'C9', 'S01', '2026-12-22 07:00', 5
SELECT @Status

-- Case 3: Member does not exist
DECLARE @Status INT
EXEC @Status = uspCreateReservation 'M00010', 'C1', 'S01', '2026-12-22 07:00', 5
SELECT @Status

-- Case 4: Bike station does not exist
DECLARE @Status INT
EXEC @Status = uspCreateReservation
    'M00002', 'C1', 'S99', '2026-12-22 07:00', 5
SELECT @Status

-- Case 5: Member not active
DECLARE @Status INT
EXEC @Status = uspCreateReservation
    'M00001', 'C1', 'S01', '2026-12-22 07:00', 5
SELECT @Status

-- Case 6: Start date in the past
DECLARE @Status INT
EXEC @Status = uspCreateReservation
    'M00002', 'C1', 'S01', '2025-01-01 07:00', 5
SELECT @Status

-- Case 7: No available bike found
DECLARE @Status INT
EXEC @Status = uspCreateReservation
    'M00002', 'C1', 'S01', '2026-12-22 07:00', 5
SELECT @Status

-- Case 8: Bike category and license mismatch
DECLARE @Status INT
EXEC @Status = uspCreateReservation
    'M00005', 'C3', 'S04', '2026-12-22 07:00', 5
SELECT @Status

