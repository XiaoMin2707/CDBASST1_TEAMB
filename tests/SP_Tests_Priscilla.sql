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

-- Case 9: NULL parameters
DECLARE @Status INT
EXEC @Status = uspCreateReservation
    'M00002', NULL, 'S01', '2026-12-22 07:00', 5
SELECT @Status