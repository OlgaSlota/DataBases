
CREATE TRIGGER [dbo].[RefuseAssignmentToCancelledReservation] 
ON [dbo].[conf_participant_list] 
AFTER INSERT, UPDATE 
AS 
BEGIN 
  DECLARE @ConferenceDayReservationId int = (SELECT conf_reservation_id FROM inserted) 

  IF ((SELECT cancelled FROM conf_reservation WHERE conf_reservation_id = @ConferenceDayReservationId) = 1)
     BEGIN 
       ;THROW 52000,'This reservation has been cancelled.',1
       ROLLBACK TRANSACTION 
     END 
 END

 -- ============================================= 
 CREATE TRIGGER [dbo].[RefuseTooManyConfParticipants] 
 ON [dbo].[Conf_participant_list] 
 AFTER INSERT, UPDATE
 AS 
 BEGIN
  DECLARE @ConferenceDayReservationId int = (SELECT conf_reservation_id FROM inserted) 
  DECLARE @reserved smallint = (SELECT places_reserved FROM conf_reservation WHERE conf_reservation_id = @ConferenceDayReservationId)
  
   IF (@reserved < (SELECT COUNT(assignment_id) FROM conf_participant_list 
                       WHERE (conf_reservation_id = @ConferenceDayReservationId)))
      BEGIN
        ;THROW 53000, 'All places has been reserved for this reservation',1
        ROLLBACK TRANSACTION 
      END 
  END

--===========================================================

CREATE TRIGGER [dbo].[RefuseTooManyLectureParticipants]
  ON [dbo].[lecture_participant_list]
    AFTER INSERT, UPDATE
AS
BEGIN
  DECLARE @LectureReservationId int = (SELECT lecture_reservation_id FROM inserted)
  DECLARE @reserved tinyint = (SELECT places_reserved
                  FROM lecture_reservation
                  WHERE lecture_reservation_id = @LectureReservationId)
  IF (@reserved < (SELECT COUNT(assignment_id) 
              FROM lecture_participant_list
              WHERE (lecture_reservation_id = @LectureReservationId)))
    BEGIN
      ;THROW 53000, 'All places for this reservation already reserved',1
      ROLLBACK TRANSACTION
    END
END

-- =============================================
 CREATE TRIGGER [dbo].[MinPlacesReservedForParticipants]
  ON [dbo].[conf_reservation]
   AFTER UPDATE
    AS 
  BEGIN
    DECLARE @ConferenceDayReservationId int = (SELECT conf_reservation_id FROM inserted)
    DECLARE @PlacesWanted smallint = (SELECT places_reserved FROM inserted) 
    DECLARE @PlacesSet smallint = (SELECT COUNT(assignment_id) FROM conf_participant_list
                            WHERE conf_reservation_id = @ConferenceDayReservationId)
    
    IF (@PlacesSet > @PlacesWanted)
      BEGIN 
        DECLARE @message varchar(100) = 'Participants assigned 
        to this reservation: '+CAST(@PlacesSet as varchar(10)) 
       ;THROW 52000,@message,1 
        ROLLBACK TRANSACTION 
       END
   END

--===========================================================

CREATE TRIGGER [dbo].[UniqueParticipantsOnList]
  ON [dbo].[conf_participant_list]
  AFTER INSERT, UPDATE
AS
BEGIN
  DECLARE @ParticipantId int = (SELECT participant_id FROM inserted)
  Declare @ConferenceDayReservationId int = (SELECT conf_reservation_id FROM inserted)

  IF(1 <(SELECT COUNT(assignment_id) FROM conf_particpant_list
         WHERE (conf_reservation_id=@ConferenceDayReservationId)
         AND (participant_id=@ParticipantId)))
    BEGIN
      ;THROW 55000, 'This participant has a place for 
      this conference day from this client', 1
      ROLLBACK TRANSACTION
    END
END

--===========================================================

CREATE TRIGGER [dbo].[TheSameDayOfConfAndLecture]
  ON [dbo].[lecture_reservation]
    AFTER INSERT, UPDATE
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @ConferenceDayId smallint = (SELECT conf_day_id
                      FROM conf_reservation
                      WHERE conf_reservation_id =
                      (SELECT conf_reservation_id
                      FROM inserted))
  DECLARE @LectureConferenceDayId smallint = (SELECT conf_day_id FROM lecture
                      WHERE lecture_id =
                      (SELECT lecture_id FROM inserted))
  IF(@ConferenceDayId <> @LectureConferenceDayId) 
  BEGIN
    ;THROW 52000,'This lecture and conference day must be the same day.',1 
    ROLLBACK TRANSACTION
  END 
END


--===========================================================

CREATE TRIGGER [dbo].[OneLectureReservationForConfDayReservation]
ON [dbo].[lecture_reservation]
   AFTER INSERT, UPDATE
AS
BEGIN
  DECLARE @ConferenceDayReservationId int = (SELECT conf_reservation_id FROM inserted)
  DECLARE @LectureId int = (SELECT lecture_id FROM inserted)

  IF(1<(SELECT count(lecture_reservation_id) FROM lecture_reservation
      WHERE(lecture_id=@LectureId) AND (conf_reservation_id=@ConferenceDayReservationId)))
    BEGIN
      ;THROW 53000, 'Some lecture places already assigned to this conf day reservation', 1
      ROLLBACK TRANSACTION
    END
END

-- ============================================= 

CREATE TRIGGER [dbo].[OnlyFutureConfSpecyfication]
  ON [dbo].[conference]
AFTER INSERT,UPDATE
AS
BEGIN 
  SET NOCOUNT ON;
  DECLARE @Date date = (SELECT begin_date FROM inserted)
  
  IF((DATEDIFF(day,GETDATE(),@Date) <= 0)) 
    BEGIN 
      ;THROW 52000,' Impossible to specify past conferences.',1
      ROLLBACK TRANSACTION
    END 
END


 --=====================================================

 CREATE TRIGGER [dbo].[DayOfConfWithinLength] 
 ON [dbo].[conf_day] 
 AFTER INSERT, UPDATE
 AS 
 BEGIN
   DECLARE @DayNumber tinyint = (SELECT day_of_conference FROM inserted) 
   DECLARE @ConferenceId smallint = (SELECT conf_id FROM inserted) 
   DECLARE @DaysAmount tinyint = (SELECT conference.length FROM conference
                             WHERE conf_id = @ConferenceId) 
   IF (@DayNumber not between 1 AND @DaysAmount)
    BEGIN 
      DECLARE @message varchar(100) = 'For this conference has been specified only ' 
                                      +CAST(@DaysAmount as varchar(3))+' days.' 
      ;THROW 52000,@message,1 
      ROLLBACK TRANSACTION 
    END 
 END

  --=================================================
  
  CREATE TRIGGER [dbo].[CheckForTwoTheSameConferenceDays]
  ON [dbo].[conf_day] 
  AFTER INSERT, UPDATE
  AS
  BEGIN 
    DECLARE @DayNumber tinyint = (SELECT day_of_conference FROM inserted)
    DECLARE @ConferenceId smallint = (SELECT conf_id FROM inserted)
  
    IF ((SELECT COUNT(conf_day_id) FROM conf_day
          WHERE (day_of_conference = @DayNumber) AND (conf_id = @ConferenceId) ) > 1) 
     
      BEGIN
        DECLARE @message varchar(100) = 'Day '+CAST(@DayNumber as varchar(3))+
                              ' already exists for this conference' 
        ;THROW 52000,@message,1
        ROLLBACK TRANSACTION
      END
  END

 --============================================

 CREATE TRIGGER [dbo].[LectureMinDuration] 
 ON [dbo].[lecture] 
 AFTER INSERT,UPDATE 
 AS 
 BEGIN
   SET NOCOUNT ON;
   DECLARE @start time(0) = (SELECT begin_time FROM inserted) 
   DECLARE @end time(0) = (SELECT end_time FROM inserted) 
  
   IF((SELECT DATEDIFF(minute,@start,@end))<20)
    BEGIN 
     ;THROW 52000,'Lecture has to last at least 20 minutes.',1 
     ROLLBACK TRANSACTION 
   END 
 END

--===========================================================

CREATE TRIGGER [dbo].[RefuseSimultaneousLectures]
  ON [dbo].[lecture_participant_list] 
  AFTER INSERT
AS 
BEGIN
  DECLARE @LectureId int = (SELECT lecture_id FROM lecture_reservation 
                       WHERE lecture_reservation_id = 
                       (SELECT lecture_reservation_id FROM inserted))
  DECLARE @BeginTime time(0) = (SELECT begin_time FROM lecture 
                                WHERE lecture_id = @LectureId)
  DECLARE @EndTime time(0) = (SELECT end_time FROM lecture 
                           WHERE lecture_id = @LectureId)
  DECLARE @ParticipantId int = (SELECT participant_id FROM lecture_participant_list 
                               WHERE lecture_reservation_id = 
                               (SELECT lecture_reservation_id FROM inserted))
  DECLARE @ConferenceDayId smallint = (SELECT conf_day_id FROM lecture 
                                      WHERE lecture_id = @LectureId)
  DECLARE @tempAssignmentId int 
  DECLARE @tempLectureId int
  DECLARE @tempBeginTime time(0) 
  DECLARE @tempEndTime time(0)

  
  DECLARE curs CURSOR LOCAL FOR
    (SELECT lpl.assignment_id FROM lecture_participant_list as lpl
      INNER JOIN lecture_reservation as lr
      ON lpl.lecture_reservation_id = lr.lecture_reservation_id
      INNER JOIN lecture as l
      ON lr.lecture_id = l.lecture_id
      WHERE (l.conf_day_id = @ConferenceDayId) AND (lpl.participant_id = @ParticipantId))

  
  OPEN curs
    FETCH NEXT FROM curs INTO @tempAssignmentId
    WHILE @@FETCH_STATUS = 0 
    BEGIN
      IF @tempAssignmentId <> (SELECT assignment_id FROM inserted) 
      BEGIN
        SET @tempLectureId = (SELECT lecture_id FROM lecture_reservation
                    WHERE lecture_reservation_id =
                    (SELECT lecture_reservation_id
                     FROM lecture_participant_list 
                     WHERE assignment_id =
                     @tempAssignmentId))

        SET @tempBeginTime = (SELECT begin_time FROM lecture
                    WHERE lecture_id = @tempLectureId)

        SET @tempEndTime = (SELECT end_time FROM lecture
                  WHERE lecture_id = @tempLectureId)

        IF (((@tempBeginTime > @BeginTime) AND(@tempBeginTime < @EndTime))
        or((@tempEndTime > @BeginTime)AND(@tempEndTime < @EndTime))
        or((@BeginTime > @tempBeginTime)AND(@BeginTime < @tempEndTime))
		 or((@EndTime > @tempBeginTime) AND(@EndTime < @tempEndTime)))

          BEGIN
            DECLARE @message varchar(100) = 'This participant is assigned
              to lecture: ' +cast(@tempLectureId as varchar(20))+
              ' which is at the same time.'
            CLOSE curs
            DEALLOCATE curs
            ;THROW 54000, @message,1 
            ROLLBACK TRANSACTION
          END
      END
      FETCH NEXT FROM curs INTO @tempAssignmentId 
    END
  CLOSE curs 
  DEALLOCATE curs
END

 --===============================================

CREATE TRIGGER [dbo].[LecturePlacesLessThanForConf] 
ON [dbo].[lecture]
  AFTER INSERT,UPDATE 
  AS
  BEGIN 
    SET NOCOUNT ON;
    DECLARE @LecturePlaces tinyint = (SELECT places FROM inserted) 
    DECLARE @ConferenceDayPlaces smallint = (SELECT C.places FROM inserted as I INNER JOIN conf_day as C 
                                        ON I.conf_day_id = C.conf_day_id) 
    IF(@LecturePlaces > @ConferenceDayPlaces)
      BEGIN
      ;THROW 52000,'Impossible to specify lecture with more places than for conference day.',1 
      ROLLBACK TRANSACTION 
  END
END


-- =============================================
 CREATE TRIGGER [dbo].[CloseReservationsForFullConfDay] 
 ON [dbo].[conf_reservation] 
 AFTER INSERT, UPDATE 
 AS 
 BEGIN 
    DECLARE @ConferenceDayId smallint = (SELECT conf_day_id FROM inserted)
    IF (dbo.GetConfPlacesLeft(@ConferenceDayId) < 0) 
      BEGIN
        DECLARE @placesLeft smallint = dbo.GetConfPlacesLeft(@ConferenceDayId) 
                     + (SELECT places_reserved FROM inserted) DECLARE @message varchar(100) = 'There are only ' 
                      +CAST(@placesLeft as varchar(10))+' places left for this conference day.'
        ;THROW 52000,@message,1  
        ROLLBACK TRANSACTION 
      END 
 END

--===========================================================

CREATE TRIGGER [dbo].[CloseReservationsForFullLecture]
ON [dbo].[lecture_reservation]
   AFTER INSERT, UPDATE
AS
BEGIN
  DECLARE @LectureId int = (SELECT lecture_id FROM inserted)
  IF(dbo.GetLecturePlacesLeft(@LectureId) < 0)
  BEGIN
    DECLARE @placesLeft tinyint=dbo.GetLecturePlacesLeft(@LectureId)
                +(SELECT places_reserved FROM INSERTED)
    DECLARE @Message varchar(100) = 'There are '
                    +CAST(@placesLeft as varchar(10))
                    +' places left for this lecture.'
    ;THROW 52000, @Message, 1
    ROLLBACK TRANSACTION
  END
END

 -- =============================================
CREATE TRIGGER [dbo].[CloseReservationsForNearConf] 
ON [dbo].[conf_reservation]
AFTER INSERT, UPDATE
AS
   BEGIN
     DECLARE @ConferenceDayId smallint = (SELECT conf_day_id FROM inserted)
     DECLARE @Date date = (SELECT reservation_date FROM inserted) 
     DECLARE @ConfBegin date = (SELECT begin_date FROM conference 
     WHERE conf_id = (SELECT conf_id FROM conf_day WHERE conf_day_id = @ConferenceDayId))
     
     IF ((DATEADD(DAY,-14,@ConfBegin)) < @Date) 
       BEGIN 
          ;THROW 53000,'The conference is starting in less than 2 weeks.',1 
          ROLLBACK TRANSACTION
       END
    END   
-- =============================================
 CREATE TRIGGER [dbo].[CloseReservationsForNoPriceConf]
 ON [dbo].[conf_reservation] 
 AFTER INSERT,UPDATE
 AS 
  BEGIN 
    SET NOCOUNT ON;
     DECLARE @Date date = (SELECT reservation_date FROM inserted) 
     DECLARE @Conference_day_id smallint = (SELECT conf_day_id FROM inserted) 
     
     IF(dbo.GetPriceStageForDate(@Date,@Conference_day_id) is null)
      BEGIN 
        ;THROW 52000,'No price for this conf day.',1 
      END
  END

  --===========================================
CREATE TRIGGER [dbo].[PriceToDateBeforeConfBegin]
ON [dbo].[conf_day_price]
AFTER INSERT, UPDATE
AS 
 BEGIN 
   DECLARE @Date date = (SELECT to_date FROM inserted) 
   DECLARE @ConferenceStartingDay date = (SELECT C.begin_date FROM inserted as I INNER JOIN conf_day as CD 
                                             ON I.conf_day_id = CD.conf_day_id INNER JOIN conference as C ON CD.conf_id = C.conf_id)
                        
   IF ((SELECT DATEDIFF(day,@Date,@ConferenceStartingDay)) < 0) 
     BEGIN
      ;THROW 52000, 'This price ends after conference begining.',1
      ROLLBACK TRANSACTION 
     END
  END

  --=====================================
  CREATE TRIGGER [dbo].[UniquePriceForDay] 
  ON [dbo].[conf_day_price]
  AFTER INSERT, UPDATE
  AS
  BEGIN
   DECLARE @InfoId int = (SELECT price_id FROM inserted) 
   DECLARE @Date date = (SELECT to_date FROM inserted) 
   DECLARE @ConferenceDayId smallint = (SELECT conf_day_id FROM inserted)
   
   IF exists(SELECT price_id FROM conf_day_price 
            WHERE ((price_id <> @InfoId)AND(to_date = @Date)AND(conf_day_id = @ConferenceDayId))) 
     BEGIN 
      ;THROW 52000, 'Impossible to add second price with the same to_date.',1 
       ROLLBACK TRANSACTION
     END
  END

   -- ============================================= 
CREATE TRIGGER [dbo].[RefuseCancelledReservationPayment] 
ON [dbo].[Payment] 
AFTER INSERT, UPDATE 
AS
  BEGIN
     SET NOCOUNT ON; 
     DECLARE @ReservationId int = (SELECT conf_reservation_id FROM inserted) 
     
     IF((SELECT cancelled FROM conf_reservation WHERE conf_reservation_id = @ReservationId)=1)
       BEGIN
         ;THROW 52000,'This reservation has been cancelled!',1 
         ROLLBACK TRANSACTION 
       END 
  END

--===========================================================

CREATE TRIGGER [dbo].[CloseReservationsForCancelledConfReservation]
ON [dbo].[lecture_reservation]
AFTER INSERT, UPDATE
AS
BEGIN
  DECLARE @ConferenceDayReservationId int = (SELECT conf_reservation_id FROM inserted) 

  IF ((SELECT cancelled FROM conf_reservation
      WHERE conf_reservation_id = @ConferenceDayReservationId) = 1) 
    BEGIN
       ;THROW 52000,'This conference day reservation has been cancelled.',1
       ROLLBACK TRANSACTION
    END
END