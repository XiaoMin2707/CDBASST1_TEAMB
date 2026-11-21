--SELECT * FROM Member;
--SELECT * FROM BikeStation
--SELECT * FROM BikeCategory;
--SELECT * FROM Motorbike;
--SELECT * FROM BikeRental;

--Stored Procedure 1 --
CREATE PROC RegisterMember
    @mem_nric CHAR(9),
    @mem_name VARCHAR(50),
    @mem_dob SMALLDATETIME,
    @mem_address VARCHAR(100),
    @mem_contact VARCHAR(15),
    @mem_email VARCHAR(50),
    @mem_licence_class VARCHAR(2)
AS
    -- Check required information
    IF @mem_nric IS NULL OR @mem_name IS NULL
       OR @mem_address IS NULL OR @mem_contact IS NULL
       OR @mem_email IS NULL OR @mem_dob IS NULL
       OR @mem_licence_class IS NULL
        RETURN -101 -- -101 => missing information

    -- Check NRIC format
    IF @mem_nric NOT LIKE '[STFGM][0-9][0-9][0-9][0-9][0-9][0-9][0-9][A-Z]'
        RETURN -102 -- -102 => invalid NRIC format

    -- Check duplicate NRIC
    IF EXISTS (SELECT * FROM Member WHERE mem_nric = @mem_nric)
        RETURN -103 -- -103 => duplicate NRIC

    -- Check duplicate email
    IF EXISTS (SELECT * FROM Member WHERE mem_email = @mem_email)
        RETURN -104 -- -104 => duplicate email

    -- Check email format
    IF @mem_email NOT LIKE '%_@_%._%'
        RETURN -105 -- -105 => invalid email format

    -- Check DOB
    IF @mem_dob > GETDATE()
        RETURN -106 -- -106 => future DOB 

    -- Check licence class
    IF @mem_licence_class NOT IN ('2B', '2A', '2')
        RETURN -107 -- -105 => invalid licence class

    -- Generate Member ID
    DECLARE @mem_id CHAR(6)
    DECLARE @next_id INT

    SELECT @next_id = ISNULL(MAX(CAST(RIGHT(mem_id, 5) AS INT)), 0) + 1
    FROM Member

    SET @mem_id = 'M' + RIGHT('00000' + CAST(@next_id AS VARCHAR(5)), 5)

    -- Insert new member
    INSERT INTO Member
    VALUES (
        @mem_id, @mem_nric, @mem_name, @mem_dob,
        @mem_address, @mem_contact, @mem_email,
        @mem_licence_class, GETDATE(), 'Pending', GETDATE()
    )

    IF @@ERROR <> 0
        RETURN -108 -- -103 => insert error

RETURN 0 -- 0 => successful
GO

--Stored Procedure 2--
CREATE PROC UpdateMemberDetails
    @mem_id CHAR(6),
    @mem_name VARCHAR(50) = NULL,
    @mem_address VARCHAR(100) = NULL,
    @mem_contact VARCHAR(15) = NULL,
    @mem_email VARCHAR(50) = NULL,
    @mem_licence_class VARCHAR(2) = NULL
AS
    -- Check if member exists
    IF NOT EXISTS (SELECT * FROM Member WHERE mem_id = @mem_id)
        RETURN -201 -- -201 => member does not exist

    -- Check if there is information to update
    IF @mem_name IS NULL AND @mem_address IS NULL
       AND @mem_contact IS NULL AND @mem_email IS NULL
       AND @mem_licence_class IS NULL
        RETURN -202 -- -202 => no information provided

    -- Check duplicate email
    IF @mem_email IS NOT NULL
       AND EXISTS (
           SELECT * FROM Member
           WHERE mem_email = @mem_email AND mem_id <> @mem_id
       )
        RETURN -203 -- -203 => duplicate email

    -- Check email format
    IF @mem_email IS NOT NULL AND @mem_email NOT LIKE '%_@_%._%'
        RETURN -204 -- -204 =>invalid email format

    -- Check licence class
    IF @mem_licence_class IS NOT NULL
       AND @mem_licence_class NOT IN ('2B', '2A', '2')
        RETURN -205 -- -205 => invalid licence class

    -- Update member information
    UPDATE Member
    SET mem_name = ISNULL(@mem_name, mem_name),
        mem_address = ISNULL(@mem_address, mem_address),
        mem_contact = ISNULL(@mem_contact, mem_contact),
        mem_email = ISNULL(@mem_email, mem_email),
        mem_licence_class = ISNULL(@mem_licence_class, mem_licence_class)
    WHERE mem_id = @mem_id

    IF @@ERROR <> 0
        RETURN -206 -- -206 => update error

RETURN 0 -- 0 => successful
GO

--Stored Procedure 3--

CREATE OR ALTER PROC UpdateMemberStatus
    @mem_id CHAR(6),
    @mem_status VARCHAR(15)
AS
    -- Check if member exists
    IF NOT EXISTS (SELECT * FROM Member WHERE mem_id = @mem_id)
        RETURN -301 -- -301 => member deos not exist

    -- Check valid status
    IF @mem_status IS NULL
       OR @mem_status NOT IN ('Pending', 'Active', 'Discontinued')
        RETURN -302 -- -302 => invalid status

    -- Check if status is already the same
    IF EXISTS (
        SELECT * FROM Member
        WHERE mem_id = @mem_id AND mem_status = @mem_status
    )
        RETURN -303 -- -303 => status same

    -- Update status and effective date
    UPDATE Member
    SET mem_status = @mem_status,
        mem_status_effective_date = GETDATE()
    WHERE mem_id = @mem_id

    IF @@ERROR <> 0
        RETURN -304 -- -304 => update error

RETURN 0 -- => successful 
GO
