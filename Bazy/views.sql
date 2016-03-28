
CREATE VIEW ClientsWithReservation AS

SELECT client.client_id as [client id] , company.company_name as name , company.phone as phone,
conf_reservation.places_reserved, conf_reservation.reservation_date ,
(select COUNT(assignment_id) from conf_participant_list
where conf_participant_list.conf_reservation_id = conf_reservation.conf_reservation_id )
as [places assigned]
FROM client join conf_reservation 
on client.client_id = conf_reservation.client_id 
inner join company 
on company.company_id = client.company_id


--=====================================================
CREATE VIEW LecturePayments AS
SELECT lr.lecture_reservation_id as "Lecture reservation id", lr.places_reserved as "Places reserved",
count(lpl.assignment_id) as "Places assigned", l.price as "Price for normal place",
l.student_discount as "student discount", count(p.student_id) as "Students included",
(l.price*lr.places_reserved) as "Price at the most", 
(cast((l.price*((count(lpl.assignment_id)-count(p.student_id))+(count(p.student_id))*(1-(l.student_discount))))as numeric(10,2)))
 as "Price for places reserved"

FROM lecture_reservation as lr
INNER JOIN lecture as l 
ON lr.lecture_id=l.lecture_id
INNER JOIN conf_day as cd
ON l.conf_day_id=cd.conf_day_id
INNER JOIN conference as c
ON cd.conf_id=c.conf_id
LEFT OUTER JOIN lecture_participant_list as lpl
ON lr.lecture_reservation_id=lpl.lecture_reservation_id
LEFT OUTER JOIN participant as p
ON (lpl.participant_id=p.participant_id AND 
DATEDIFF(day, c.begin_date, p.student_id_expiration_date)>=0)
GROUP BY lr.lecture_reservation_id, lr.places_reserved,l.price,l.student_discount

--=======================================
CREATE VIEW ConfDayPayments AS 

SELECT c.conf_id, cr.conf_reservation_id , cr.conf_day_id ,cr.client_id ,cr.reservation_date ,
  cr.places_reserved as [places reserved], count(assignment_id) as [places assigned],
  count (p.student_id) as students , (CAST((pr.price *((count(cr.conf_reservation_id) - count(p.student_id))
  +count(p.student_id)*cd.student_discount)) as numeric(10,2))) as 'Conference day act price',
  (dbo.GetPriceStageForDate(cr.reservation_date,cr.conf_day_id) * cr.places_reserved) as 'Conference day max price',
  (isnull(WI.act_price,0)) as 'Lectures act price',
  isnull((WI.up_price),0) as 'Lectures max price'

FROM conf_reservation as cr 
join conf_day as cd
on cr.conf_day_id = cd.conf_day_id
join conference as c 
on c.conf_id = cd.conf_id
left join conf_participant_list as cpl
on cpl.conf_reservation_id = cr.conf_reservation_id
left join participant as p
on p.participant_id=cpl.participant_id AND(DATEDIFF(day,c.begin_date,p.student_id_expiration_date)>=0)
join conf_day_price as pr
on pr.price_id = (dbo.GetConfPriceID(cr.reservation_date,cr.conf_day_id))
left join (SELECT [Lecture reservation id] as conf_day_reservation, sum([Price for places reserved]) as act_price, 
sum([Price at the most]) as up_price 
FROM LecturePayments
GROUP BY [Lecture reservation id]) as WI 
ON cr.conf_reservation_id = WI.conf_day_reservation
GROUP BY cr.conf_reservation_id, cr.conf_day_id, cr.client_id, cr.reservation_date, cr.places_reserved, 
pr.price, cd.student_discount, c.conf_id, WI.act_price, WI.up_price

--=====================================================
CREATE VIEW ConfPayments AS
SELECT client_id, conf_id,
cast((sum([Conference day act price])+sum([Lectures act price])) as numeric(10,2))
as 'Act price to pay for conference',
cast((sum([Conference day max price])+sum([Lectures max price])) as numeric(10,2))
as 'Max price to pay for conference'

FROM ConfDayPayments
GROUP BY client_id, conf_id

--=====================================================
CREATE VIEW AvailableLectures AS
SELECT cd.conf_day_id as "Conference Day ID", l.lecture_id as "Lecture ID",
dbo.GetLecturePlacesLeft(lecture_id) as "Places left", l.price as "Price", 
l.student_discount*100 as "Student discount in percents", (DATEADD(day, 1, c.begin_date)) as "Lecture date",
l.begin_time as "Begin time", l.end_time as "End time"
FROM lecture as l
INNER JOIN conf_day as cd
ON l.conf_day_id=cd.conf_day_id
INNER JOIN conference as c 
ON cd.conf_id=c.conf_id
WHERE (dbo.GetLecturePlacesLeft(lecture_id)>0)

--=====================================================
CREATE VIEW BestCustomers AS
SELECT c.client_id as "Client ID", c.bank_account_number as "Client Account Number", 
c.company_id as "Company ID if applicable", com.company_name as "Company name", 
com.phone as "Company phone number", SUM(cr.places_reserved) AS "Total places reserved",
SUM(p.paid) AS "Totalpayments", COUNT (DISTINCT cd.conf_id) AS "Conferences participated"

FROM client as c 
INNER JOIN conf_reservation as cr
ON c.client_id=cr.client_id
INNER JOIN payment as p 
ON cr.conf_reservation_id=p.conf_reservation_id
INNER JOIN conf_day as cd
ON cr.conf_day_id=cd.conf_day_id
INNER JOIN company as com
ON c.company_id=com.company_id
GROUP BY c.client_id,c.bank_account_number,c.company_id,company_name,phone
--=====================================================
CREATE VIEW ConfDayParticipants AS
SELECT cr.conf_day_id, p.participant_id, p.first_name, p.last_name, cr.client_id

FROM conf_reservation as cr
INNER JOIN conf_participant_list as cpl 
ON cr.conf_reservation_id=cpl.conf_reservation_id
INNER JOIN participant as p 
ON cpl.participant_id=p.participant_id
GROUP BY cr.conf_day_id,p.participant_id,first_name,last_name,cr.client_id

--=====================================================
CREATE VIEW LectureParticipants AS 

SELECT lr.lecture_id, p.participant_id, p.first_name, p.last_name, cr.client_id
FROM lecture_reservation as lr
INNER JOIN lecture_participant_list as lpl 
ON lr.lecture_reservation_id=lpl.lecture_reservation_id
INNER JOIN participant as p 
ON lpl.participant_id=p.participant_id
INNER JOIN conf_reservation as cr 
ON cr.conf_reservation_id=lr.conf_reservation_id
GROUP BY lr.lecture_id,p.participant_id, p.first_name, p.last_name, cr.client_id

--=====================================================
CREATE VIEW ToPay AS
SELECT p.conf_reservation_id as "Conference day reservation id", cast(SUM(p.paid) as numeric(10,2)) 
as "Paid money", cast(cb.[Conference day act price]+cb.[Lectures act price] as numeric(10,2)) 
as "Act price to pay for reservation",
cast(cb.[Conference day max price]+cb.[Lectures max price] as numeric(10,2))
as "Max price to pay for reservation"

FROM payment as p
INNER JOIN ConfDayPayments as cb
ON p.conf_reservation_id=cb.conf_reservation_id
GROUP BY (cb.[Conference day act price]+cb.[Lectures act price]), 
(cb.[Conference day max price]+cb.[Lectures max price]), p.conf_reservation_id


--=====================================================
CREATE VIEW WeekAfterPartialyPaidReservation AS
SELECT CI.conf_reservation_id, CI.reservation_date, c.conf_id, c.begin_date, CI.[places reserved], CI.[Places assigned],
  isnull(PAI.[Paid money],0) as 'Paid money', CI.client_id, company.company_name as 'Client name',
  company.phone as 'Client phone',ISNULL( CL.company_id, 'no') as 'Is company'
FROM ConfDayPayments as CI 
LEFT OUTER JOIN ToPay as PAI
ON (CI.conf_reservation_id = PAI.[Conference day reservation id])AND(PAI.[Paid money] > (CI.[Conference day act price]+CI.[Lectures act price])) 
INNER JOIN conf_reservation as cr ON (CI.conf_reservation_id = cr.conf_reservation_id)AND((cr.cancelled = 0))
INNER JOIN conf_day as cd
ON CI.conf_day_id = cd.conf_day_id 
INNER JOIN conference as c
ON cd.conf_id = c.conf_id 
INNER JOIN Client as CL 
ON CI.client_id = CL.client_id
LEFT JOIN company
on company.company_id = CL.company_id
 --Date 14 or less days before conference is starting, but still before conference 
 WHERE ((DATEDIFF(day, GETDATE(), c.begin_date) <= 14) AND (DATEDIFF(day, GETDATE(), c.begin_date) >= 0))
 