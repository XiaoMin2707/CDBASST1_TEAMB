CREATE PROC uspCreateReservation (@MemberID CHAR(6) = NULL, @BikeCatID CHAR(2) = NULL , @StationID CHAR(3) = NULL, @StartDateTime SMALLDATETIME = NULL, @RentDurationDays TINYINT = NULL)
AS
	DECLARE @MemberAge INTEGER, @MemberLicenceClass VARCHAR(2), @AssignedBike CHAR(5), @MemberStatus VARCHAR(15) --, @CatLicenceClass VARCHAR(2)

	IF @BikeCatID IS NULL
		RETURN -200 -- Bike catgory ID cannot be null
	IF @StationID IS NULL
		RETURN -201 -- Station ID cannot be null
	IF @StartDateTime IS NULL
		RETURN -202 -- Start date and time cannot be null
	IF @RentDurationDays IS NULL
		RETURN -203 -- Rent duration in days cannot be null

	
	SELECT @MemberStatus = mem_status
	FROM Member
	WHERE mem_id = @MemberID

	IF @MemberStatus = 'Active'
	BEGIN
		SELECT @MemberAge = DATEDIFF(YEAR, mem_dob, GETDATE())
		FROM Member
		WHERE mem_id = @MemberID
		IF @MemberAge >= 22 AND @MemberAge <= 65
		BEGIN
			SELECT @MemberLicenceClass = mem_licence_class
			FROM Member
			WHERE mem_id = @MemberID

			--SELECT @CatLicenseClass = c.cat_license_class
			--FROM BikeCategory c INNER JOIN Motorbike b
			--ON c.cat_id = b.bike_category

			--IF @MemberLicenceClass == @CatLicenceClass
				IF @StartDateTime >= GETDATE()
				BEGIN
					SELECT TOP 1 @AssignedBike = b.bike_id
					FROM Motorbike b INNER JOIN BikeCategory c
					ON b.bike_category = c.cat_id
					WHERE b.bike_status = 'Available' AND c.cat_licence_class = @MemberLicenceClass
					IF @AssignedBike IS NULL
						RETURN -208 -- No available bike found
					ELSE
					BEGIN
						INSERT INTO BikeRental (rent_start_date, rent_duration, rent_return_date, rent_extra_km, rent_total_cost, rent_memberid, rent_bikeid)
						VALUES (@StartDateTime, @RentDurationDays, '2079-06-06', 0, 0, @MemberID, @AssignedBike)
					END
				END
				ELSE
					RETURN -206 -- Start date and time cannot be before today's date

		END
		ELSE
			RETURN -205 -- Member's age is not between 22 to 65 years old, hence not eligible to rent a bike
	END		
	ELSE
		RETURN -204 -- Member status is not active

RETURN
GO

--DROP PROC uspCreateReservation

DECLARE @Status INT
EXEC @Status = uspCreateReservation 'M00002', 'C1', 'S01', '2026-11-22 07:00', 5
SELECT @Status