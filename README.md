# CDBASST1_TEAMB
CDB Assignment 1 – Motorbike Rental System (CDBRental)
**Deadline:** 6 Dec 2026, 23:59

## Overview
We are given a database for a made-up motorbike rental company called CDBRental. The tables and sample data come from `CDB26Asg1Script.sql` (PoliteMall). Our job is to write SQL Server code that keeps bad data out of the database, using stored procedures, views and triggers.

**Tables (5):** Member, BikeStation, BikeCategory, Motorbike, BikeRental
> ⚠️ We **cannot modify** the given tables, but we can add new tables and sample data.

## Business Rules
- Only **Active** members aged **22–65** can rent.
- Member's licence class must match the bike category's licence class.
- Members reserve by giving category, station, start date/time and number of days. The system assigns an available bike that fits.
- Pickup from **7am**. Latest return is **7pm** on the due date. Bike returns to the same station.
- On return, record return date/time and km driven. Each rental day includes **20 free km**.
- **Total cost** = days × daily rate + extra km × distance rate + hours late × late penalty rate

## Deliverables
| Item | Who | Minimum |
|---|---|---|
| Stored procedure | Each person (individual) | 1 each (select/insert/update/delete) |
| Views | Team | 2 |
| Trigger | Team | 1 |

Submission: one `.sql` file + cover page, zipped, uploaded to PoliteMall. 20-min presentation + Q&A.

## Grading
- **70% Individual:** your own stored procedure (validation, error handling, input/output parameters, naming, comments, clear error messages, demo and explanation)
- **30% Team:** views, triggers, and how everything works together as one solution
- More complex and useful = more marks. Don't just do the bare minimum.

## Roles & Responsibilities

### Jia Xuan – Members (`Members/`)
- **Stored procedure:** register a new member (insert) or change member status (update)
- **Checks:** NRIC format, no duplicate NRIC/email, valid licence class, new members start as 'Pending', status can only be Pending/Active/Discontinued
- **Team item:** View 1 – available bikes for members (bike, category rates, station; hides internal columns)

### Priscilla – Reservations (`Reservations/`)
- **Stored procedure:** make a reservation (insert into BikeRental)
- **Checks:** member is Active, age 22–65, licence class matches category, pickup at or after 7am and not in the past, valid duration
- Find and assign an available bike at that station and category, with no overlapping booking
- **Team item:** Trigger 1 – set bike to 'Not Available' when a rental is created

### Si Yu – Returns (`Returns/`)
- **Stored procedure:** process a return (update BikeRental)
- **Checks:** rental exists and isn't already returned, return time is after start time
- Calculate extra km (over 20 km × days), hours late after 7pm on due date, and total cost (OUTPUT parameter)
- **Team item:** Trigger 2 – set bike back to 'Available' on return (or combine with Trigger 1)

### Calista – Fleet + Integrator (`Fleet/`, `finals/`)
- **Stored procedure:** add a bike (insert) or remove a bike (delete), or rental history / invoice lookup (select)
- **Checks:** unique plate number, category and station exist, engine cc fits category, can't delete a bike that's currently rented
- **Team item:** View 2 – outstanding / overdue rentals for staff
- **Integrator:** combine everyone's code into one `.sql`, add name/ID labels, run whole script from scratch, zip and submit with cover page

## Folder Structure
| Folder | Purpose |
|---|---|
| `Set-up/` | Given script – run this first, **don't edit** |
| `Members/`, `Reservations/`, `Returns/`, `Fleet/` | Each person's own SP, view/trigger and test calls |
| `tests/` | Shared extra sample data for testing |
| `finals/` | Merged submission file – **only Calista edits** |

## Shared Rules (to agree as a team)
- [ ] Who updates `bike_status` – the SPs or the triggers? (Don't do both)
- [ ] How to count hours late (e.g. round up partial hours?)
- [ ] Naming: `usp_` for procedures, `vw_` for views, `trg_` for triggers
- [ ] Error message style (e.g. RAISERROR / PRINT / TRY…CATCH)
- [ ] Each file starts with a comment header: name, student ID, description

## Run Order
1. `Set-up/CDB26Asg1Script.sql`
2. `tests/` extra sample data
3. Each person's files
4. Test calls

## Git Workflow
- Only edit files in **your own folder**
- `git pull` before you start working
- Commit often with clear messages, e.g. `Add age validation to reservation SP`
- `git push` when done
- Keep the repo **private**

## Timeline
- **~10 Nov:** everyone set up, script loaded, shared rules agreed
- **~24 Nov:** individual SPs working and tested; views and triggers drafted
- **~1 Dec:** merge into one script, run from scratch, add comments
- **Before 6 Dec:** rehearse 20-min demo, zip and submit
