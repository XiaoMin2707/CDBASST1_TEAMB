-- Trigger 1
/* Purpose of Trigger 1: Set the system-assigned bike to 'Not available' so that
the reserved bike cannot be assigned to anyone else, preventing double bookings */

CREATE TRIGGER trigSetBikeNotAvailableReservation
ON BikeRental
AFTER INSERT
AS
BEGIN
    /* Prevents SQL from sending back a message depicting the number of rows 
    affected for the update statement in the trigger, which otherwise might confuse
    the CreateReservation SP. */
    SET NOCOUNT ON;

    -- Handles insert statements that did not come from the SP
    IF EXISTS (SELECT 1
               FROM inserted i INNER JOIN Motorbike m 
               ON m.bike_id = i.rent_bikeid
               WHERE m.bike_status <> 'Available')
    BEGIN
        PRINT ('Bike is not available for reservation')
        ROLLBACK TRANSACTION
    END

    ELSE
        UPDATE m
        SET    m.bike_status = 'Not Available'
        FROM   Motorbike m
        INNER JOIN inserted i ON m.bike_id = i.rent_bikeid;
END
GO

