-- task:handle the bikes available to rent
/*SELECT* FROM BikeCategory
SELECT* FROM Motorbike
SELECT* FROM BikeStation*/ 

DROP PROCEDURE IF EXISTS uspAddMotorbike;
GO

CREATE PROCEDURE uspAddMotorbike
@BikeID char(5),
@PlateNumber varchar(8),
@Brand varchar(15),
@Model varchar(20),
@EngineCC decimal(5,1),
@CategoryID char(2),
@StationID char(3)

AS
BEGIN
INSERT INTO Motorbike (bike_id, bike_plate_number, bike_brand, bike_model, bike_engine_cc, bike_status, bike_category, bike_station)
VALUES (@BikeID, @PlateNumber,  @Brand, @Model, @EngineCC, 'Available', @CategoryID, @StationID);
IF @@ERROR <> 0       
        RETURN -8;        

    RETURN 0;             
END
GO