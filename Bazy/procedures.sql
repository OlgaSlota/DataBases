use sosnowsk_a
-- =============================================
 CREATE PROCEDURE [dbo].[NewClient]
  @company int,
  @account int
  AS
    BEGIN
      SET NOCOUNT ON;
      INSERT INTO client( company_id , bank_account_number)
      VALUES(@company, @account)
    END
-- =============================================
 CREATE PROCEDURE [dbo].[NewCompany]
  @name int,
  @phone int
  AS
   BEGIN
       SET NOCOUNT ON;
       INSERT INTO company(company_name , phone)
       VALUES(@name, @phone) 
   END

-- =============================================
 CREATE PROCEDURE [dbo].[NewConference]
  @len tinyint,
  @begin date
  AS
  BEGIN
        SET NOCOUNT ON;
        INSERT INTO conference( length , begin_date)
        VALUES(@len, @begin) 
  END

-- =============================================
 CREATE PROCEDURE [dbo].[NewConfDay]
  @conf_id smallint,
  @places smallint,
  @discount decimal(5, 2),
  @day_no tinyint
  AS
    BEGIN
        SET NOCOUNT ON;
        INSERT INTO conf_day(conf_id,places, student_discount, day_of_conference)
        VALUES(@conf_id,@places, @discount, @day_no ) 
    END

-- =============================================
 CREATE PROCEDURE [dbo].[NewParticipant]
  @student_id int,
  @last nvarchar(20),
  @first nvarchar(20),
  @company int,
  @student_date date
  AS
    BEGIN
       SET NOCOUNT ON;
       INSERT INTO participant(student_id , last_name , first_name , company_id, student_id_expiration_date)
       VALUES(@student_id, @last , @first,@company, @student_date) 
    END

-- =============================================
 CREATE PROCEDURE [dbo].[NewLecture]
  @day_id smallint,
  @pr money,
  @pl tinyint,
  @begin time(7),
  @end time(7),
  @student decimal(5,2)
  AS
    BEGIN
       SET NOCOUNT ON;
       INSERT INTO lecture(conf_day_id , price , places , begin_time , end_time, student_discount)
       VALUES(@day_id, @pr,@pl , @begin , @end, @student) 
    END

-- =============================================
 CREATE PROCEDURE [dbo].[NewPayment]
  @reservation_id int,
  @paid money
  AS
    BEGIN
       SET NOCOUNT ON;
       INSERT INTO payment(conf_reservation_id , paid)
       VALUES( @reservation_id,@paid) 
    END

-- =============================================
 CREATE PROCEDURE [dbo].[NewConfDayPrice]
  @day_id int,
  @pr money,
  @to date
  AS
    BEGIN
       SET NOCOUNT ON;
       INSERT INTO conf_day_price(conf_day_id,price,to_date)
       VALUES(@day_id, @pr, @to) 
    END

-- =============================================
 CREATE PROCEDURE [dbo].[ParticipateConf]
  @reservation_id int,
  @paticip_id int
  AS
    BEGIN
       SET NOCOUNT ON;
       INSERT INTO conf_participant_list(conf_reservation_id,participant_id)
       VALUES(@reservation_id,@paticip_id) 
    END

-- =============================================
CREATE PROCEDURE [dbo].[ParticipateLecture]
 @reservation_id int,
 @particip_id int
 AS
  BEGIN
    SET NOCOUNT ON;

    DECLARE @ConferenceDayReservationId int = (SELECT conf_reservation_id
                                               FROM lecture_reservation
                                               WHERE lecture_reservation_id = @reservation_id) 
    
    DECLARE @AssignmentId int = (SELECT assignment_id
                                             FROM conf_participant_list 
                                             WHERE (participant_id = @particip_id) 
                                             AND (conf_reservation_id = @ConferenceDayReservationId)) 
    
    IF (@AssignmentId is null) 
      BEGIN 
        ;THROW 52000, 'Participant has not been assigned to 
        appropriate conference day reservation. Cannot assign to him to lecture.',1 
      END

    INSERT INTO lecture_participant_list(lecture_reservation_id,participant_id)
    VALUES(@reservation_id,@particip_id) 
  END

-- =============================================
 CREATE PROCEDURE [dbo].[ConfReservation]
  @day_id smallint,
  @client int,
  @places smallint
  AS
    BEGIN
      SET NOCOUNT ON;
      INSERT INTO conf_reservation(conf_day_id,client_id, places_reserved, reservation_date)
      VALUES(@day_id,@client, @places, GETDATE()) 
    END

-- =============================================
 CREATE PROCEDURE [dbo].[LectureReservation]
  @lecture_id int,
  @conf_reservation int,
  @places smallint
  AS
    BEGIN
      SET NOCOUNT ON;
      INSERT INTO lecture_reservation(lecture_id,conf_reservation_id, places_reserved)
      VALUES(@lecture_id,@conf_reservation, @places) 
    END

-- =============================================
CREATE PROCEDURE [dbo].[CancelLectureReservation]
  @LectureReservationId int
AS
BEGIN
  SET NOCOUNT ON;
  
  IF((SELECT cancelled FROM lecture_reservation WHERE lecture_reservation_id=@LectureReservationId)=1)
    BEGIN
      ;THROW 52000, 'This reservation has already been cancelled', 1
    END
  ELSE
      BEGIN TRY
        BEGIN TRAN
            DELETE FROM lecture_participant_list
            WHERE lecture_participant_list.lecture_reservation_id=@LectureReservationId

            UPDATE lecture_reservation
            SET lecture_reservation.cancelled=1
            WHERE lecture_reservation.lecture_reservation_id=@LectureReservationId
        COMMIT TRAN
      END TRY
      BEGIN CATCH
        print error_message()
        ROLLBACK TRANSACTION
      END CATCH
END

-- =============================================
CREATE PROCEDURE [dbo].[CancelConfDayReservation]
  @ConfReservationId int
AS 
BEGIN
  SET NOCOUNT ON;
  
  IF not exists(SELECT * FROM conf_reservation
              WHERE conf_reservation.conf_reservation_id= @ConfReservationId)
    BEGIN
       DECLARE @message varchar(100) = 'Cannot cancel conference day reservation '
       +@ConfReservationId+ '. It does not exists'
       ;THROW 51000,@message,1 
    END

  ELSE
    IF ((SELECT cancelled FROM conf_reservation
           WHERE conf_reservation_id = @ConfReservationId) = 1) 
      BEGIN
        ;THROW 52000,'This reservation has already been cancelled.',1
      END 
    ELSE
       DECLARE @LectureReservationId int 
       DECLARE curs CURSOR LOCAL FOR
                 SELECT lecture_reservation.lecture_reservation_id
                 FROM lecture_reservation
                 WHERE lecture_reservation.conf_reservation_id=
                @ConfReservationId
       OPEN curs 
       BEGIN TRY
           BEGIN TRAN
     
              FETCH NEXT FROM curs INTO @LectureReservationId

              WHILE @@FETCH_STATUS = 0 
                BEGIN 
                   BEGIN TRY
                      exec CancelLectureReservation @LectureReservationId
                   END TRY
                   BEGIN CATCH
                       PRINT 'Reservation '+@LectureReservationId+' has been
                       removed from database becouse of cancelling reservation'
                   END CATCH
                   FETCH NEXT FROM curs INTO @LectureReservationId
                END

      --cancelling participant'sreservations
             DELETE FROM conf_participant_list
             WHERE conf_reservation_id = @ConfReservationId
             
             UPDATE conf_reservation 
             SET cancelled = 1
             WHERE conf_reservation_id = @ConfReservationId
      CLOSE curs
      DEALLOCATE curs 
      COMMIT TRAN
      END TRY 
      BEGIN CATCH
          CLOSE curs
          DEALLOCATE curs
          print error_message() 
          ROLLBACK TRANSACTION
      END CATCH

END

-- =============================================
CREATE PROCEDURE [dbo].[CancelUnpaidConfDayReservation]

AS
BEGIN
  SET NOCOUNT ON;

  DECLARE curs CURSOR LOCAL FOR
    (SELECT cdpi.conf_reservation_id, cdpi.reservation_date
    FROM ConfDayPayments as cdpi
    LEFT OUTER JOIN ToPay as pai
    ON (cdpi.conf_reservation_id=pai.[Conference day reservation id])
    AND (pai.[Paid money] < (cdpi.[Conference day act price]+cdpi.[Lectures act price]))
    INNER JOIN conf_reservation as cr 
    ON (cdpi.conf_reservation_id=cr.conf_reservation_id)
    AND (isnull(cr.cancelled,0)=0))

  DECLARE @ReservationID int, @ReservationDate date 

  OPEN curs
    FETCH NEXT FROM curs INTO @ReservationID, @ReservationDate
    WHILE @@FETCH_STATUS=0
    BEGIN 
      IF(DATEDIFF(day, @ReservationDate, GETDATE())>7)
        BEGIN
           exec CancelConfDayReservation @ReservationID
        END
      FETCH NEXT FROM curs INTO @ReservationID, @ReservationDate
    END
  CLOSE curs
  DEALLOCATE curs
END


-- =============================================
CREATE PROCEDURE [dbo].[SetLecturePlacesNumber]
  @LectureReservationId int,
  @PlacesAmount int 
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE lecture_reservation
  SET places_reserved = @PlacesAmount 
  WHERE lecture_reservation_id = @LectureReservationId
END

-- =============================================
CREATE PROCEDURE [dbo].[ReduceConfPlacesNumber]
  @ConfReservationId int,
  @PlacesAmount int 
AS
BEGIN
  SET NOCOUNT ON;
  
  IF((SELECT places_reserved
      FROM conf_reservation
      WHERE conf_reservation_id=@ConfReservationId)<@PlacesAmount)
  BEGIN
    ;THROW 52000, 'You can only make a new reservation to add places.',1
  END
  ELSE
  BEGIN
      UPDATE conf_reservation
      SET places_reserved=@PlacesAmount
      WHERE conf_reservation_id=@ConfReservationId
  END
END

-- =============================================
CREATE PROCEDURE [dbo].[DelFromConfParticipantList]
  @ConfReservationId int,
  @ParticipantID int
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    BEGIN TRAN
      DELETE FROM lecture_participant_list
      WHERE participant_id=@ParticipantID
      AND lecture_reservation_id=(SELECT lecture_reservation_id
                                  FROM lecture_reservation
                                  WHERE conf_reservation_id=@ConfReservationId)

      DELETE FROM conf_participant_list
      WHERE participant_id=@ParticipantID
      AND conf_reservation_id=@ConfReservationId

    COMMIT TRAN
  END TRY
  BEGIN CATCH
    print error_message()
    ROLLBACK TRANSACTION
  END CATCH
END

-- =============================================
CREATE PROCEDURE [dbo].[DelFromLectureParticipantList]
  @LectureReservationId int,
  @ParticipantID int
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    BEGIN TRAN
      DELETE FROM lecture_participant_list
      WHERE lecture_reservation_id=@LectureReservationId
      AND participant_id=@ParticipantID
    COMMIT TRAN
 
  END TRY
  BEGIN CATCH
    print error_message()
    ROLLBACK TRANSACTION
  END CATCH
END

-- =============================================
CREATE PROCEDURE [dbo].[ExtendPlacesForConfDay]
  @ConfDayId int,
  @PlacesAmount int
AS
BEGIN
  SET NOCOUNT ON;

  IF(@PlacesAmount<= (SELECT places FROM conf_day WHERE conf_day_id=@ConfDayId))
  BEGIN 
    ;THROW 52000, 'You cannot narrow down number of places for conference day', 1
  END
  ELSE
      UPDATE conf_day
      SET places=@PlacesAmount
      WHERE conf_day_id=@ConfDayId
END

-- =============================================
CREATE PROCEDURE [dbo].[ExtendPlacesForLecture]
  @LectureId int,
  @PlacesAmount int
AS
BEGIN
  SET NOCOUNT ON;

  IF(@PlacesAmount<= (SELECT places FROM lecture WHERE lecture_id=@LectureId))
  BEGIN 
    ;THROW 52000, 'You cannot narrow down number of places for lecture', 1
  END
  ELSE
      UPDATE lecture
      SET places=@PlacesAmount
      WHERE lecture_id=@LectureId
END
-- =============================================
CREATE PROCEDURE [dbo].[GEN_ConfReservation]
  @day_id smallint,
  @client int,
  @places smallint,
  @res_date date
  AS
    BEGIN
       SET NOCOUNT ON;
       INSERT INTO conf_reservation(conf_day_id,client_id, places_reserved, reservation_date)
       VALUES(@day_id,@client, @places, @res_date) 
END