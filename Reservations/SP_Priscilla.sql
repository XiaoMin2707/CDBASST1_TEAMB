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

			SELECT @CatLicenceClass = cat_licence_class
			FROM BikeCategory
			WHERE cat_id = @BikeCatID

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

