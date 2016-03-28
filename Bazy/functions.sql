CREATE FUNCTION [dbo].[GetConfPlacesLeft] 
( @ConferenceDayId smallint )
	RETURNS smallint 
AS
BEGIN
	IF not exists (SELECT conf_day.conf_day_id
                    FROM conf_day 
					WHERE conf_day.conf_day_id = @ConferenceDayId)
	  BEGIN
    	RETURN 0 
  	  END

 	ELSE 
 	  BEGIN

    	DECLARE @placesLeft smallint 
    	DECLARE curs CURSOR LOCAL FOR
        	SELECT places_reserved
        	FROM conf_reservation 
      	    WHERE conf_day_id = @ConferenceDayId 
	    DECLARE @reserved smallint

	  	-- Get all places 
	    SET @placesLeft = (SELECT places FROM conf_day 
		                   WHERE conf_day_id = @ConferenceDayId) 

	  	-- booked places 
	    SET @reserved = (SELECT sum(places_reserved) FROM conf_reservation
   	  	                 WHERE (conf_day_id = @ConferenceDayId) AND (isnull(cancelled,0) = 0) 
	  	                 GROUP BY conf_day_id )
	  
    	IF(@reserved is not null) 
        	SET @placesLeft -= @reserved 
   	  END 

	RETURN @placesLeft
END

--=========================================================

CREATE FUNCTION [dbo].[GetLecturePlacesLeft]
(
	@LectureId int
)
RETURNS tinyint
AS
BEGIN
	IF not exists (SELECT lecture_id
					FROM lecture
					WHERE lecture_id=@LectureId)
	BEGIN
		RETURN 0
	END
	ELSE
	BEGIN
		-- Get whole amount of free places
		DECLARE @placesLeft tinyint = (SELECT places FROM lecture
									WHERE lecture_id=@LectureId)
		DECLARE curs CURSOR LOCAL FOR 
				SELECT places_reserved
				FROM lecture_reservation
				WHERE lecture_id=@LectureId
		DECLARE @reserved tinyint

		-- Substract booked places
		SET @reserved = (SELECT sum(places_reserved)
								FROM lecture_reservation
								WHERE (lecture_id=@LectureId) AND 
								(isnull(cancelled,0)=0)
								GROUP BY lecture_id)
		IF(@reserved is not null)
			SET @placesLeft -= @reserved
		END
	-- Return the result of the function
	RETURN @placesLeft 
END

--=========================================================

CREATE FUNCTION [dbo].[GetConfPriceID]
( 
 @Date date, 
 @ConferenceDayId smallint 
)
RETURNS int

AS
BEGIN

  DECLARE @PriceId int = (SELECT TOP 1 price_id FROM conf_day_price
                 	WHERE (conf_day_id = @ConferenceDayId) AND (DATEDIFF(day,@date,to_date) >= 0) 
	                ORDER BY to_date) 

  RETURN @PriceId
END

--=========================================================
CREATE FUNCTION [dbo].[GetPriceStageForDate]
( 
 @Date date, 
 @ConferenceDayId smallint 
)
RETURNS money

AS
BEGIN 

  DECLARE @Price money = (SELECT TOP 1 price FROM conf_day_price
                 	WHERE (conf_day_id = @ConferenceDayId) AND (DATEDIFF(day,@date,to_date) >= 0)
		            ORDER BY to_date)

	RETURN @Price
END