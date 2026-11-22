-- task:handle the bikes available to rent
/*SELECT* FROM BikeCategory
SELECT* FROM Motorbike
SELECT* FROM BikeStation*/ 

DROP PROCEDURE IF EXISTS uspAddMotorbike;
GO

CREATE PROC uspAddMotorbike
    @BikeID CHAR(5), @PlateNumber VARCHAR(8), @Brand VARCHAR(15),
    @Model VARCHAR(20), @EngineCC DECIMAL(5,1),
    @CategoryID CHAR(2), @StationID CHAR(3)
AS
    IF @BikeID IS NULL OR @PlateNumber IS NULL OR @Brand IS NULL OR @Model IS NULL
       OR @EngineCC IS NULL OR @CategoryID IS NULL OR @StationID IS NULL
        RETURN -601 -- -601 => missing information

    IF EXISTS (SELECT * FROM Motorbike WHERE bike_id = @BikeID)
        RETURN -602 -- -602 => duplicate bike ID

    IF EXISTS (SELECT * FROM Motorbike WHERE bike_plate_number = @PlateNumber)
        RETURN -603 -- -603 => duplicate plate number

    IF NOT EXISTS (SELECT * FROM BikeCategory WHERE cat_id = @CategoryID)
        RETURN -604 -- -604 => category does not exist

    IF NOT EXISTS (SELECT * FROM BikeStation WHERE stat_id = @StationID)
        RETURN -605 -- -605 => station does not exist

    IF @EngineCC <= 0
        RETURN -606 -- -606 => invalid engine cc

    -- Optional: engine cc must match the category's licence class
    -- (2B up to 200cc, 2A 201-400cc, 2 above 400cc)
    DECLARE @CatLicence VARCHAR(2)
    SELECT @CatLicence = cat_licence_class FROM BikeCategory WHERE cat_id = @CategoryID
    IF (@CatLicence = '2B' AND @EngineCC > 200)
       OR (@CatLicence = '2A' AND (@EngineCC <= 200 OR @EngineCC > 400))
       OR (@CatLicence = '2' AND @EngineCC <= 400)
        RETURN -607 -- -607 => engine cc does not match category licence class

    INSERT INTO Motorbike (bike_id, bike_plate_number, bike_brand, bike_model,
                           bike_engine_cc, bike_status, bike_category, bike_station)
    VALUES (@BikeID, @PlateNumber, @Brand, @Model, @EngineCC,
            'Available', @CategoryID, @StationID)

    IF @@ERROR <> 0
        RETURN -608 -- -608 => insert error

RETURN 0 -- 0 => successful
GO

CREATE PROC uspUpdateBikeStatus
    @BikeID CHAR(5),
    @Status VARCHAR(15)
AS
    IF @BikeID IS NULL OR @Status IS NULL
        RETURN -701 -- -701 => missing information

    IF NOT EXISTS (SELECT * FROM Motorbike WHERE bike_id = @BikeID)
        RETURN -702 -- -702 => bike does not exist

    IF @Status NOT IN ('Available', 'Rented', 'Maintenance', 'Retired')
        RETURN -703 -- -703 => invalid status

    IF EXISTS (SELECT * FROM Motorbike WHERE bike_id = @BikeID AND bike_status = @Status)
        RETURN -704 -- -704 => status is already the same

    -- Cannot take a bike out of service while it has an unreturned rental
    -- (team convention: rent_total_cost = 0 means not yet returned)
    IF @Status IN ('Maintenance', 'Retired')
       AND EXISTS (SELECT * FROM BikeRental
                   WHERE rent_bikeid = @BikeID AND rent_total_cost = 0)
        RETURN -705 -- -705 => bike has an unreturned rental

    -- A retired bike is permanently out of service
    IF EXISTS (SELECT * FROM Motorbike WHERE bike_id = @BikeID AND bike_status = 'Retired')
        RETURN -706 -- -706 => retired bike cannot change status

    UPDATE Motorbike
    SET bike_status = @Status
    WHERE bike_id = @BikeID

    IF @@ERROR <> 0
        RETURN -707 -- -707 => update error

RETURN 0 -- 0 => successful
GO