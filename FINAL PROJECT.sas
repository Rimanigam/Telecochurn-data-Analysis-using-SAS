LIBNAME RIMA "C:\Users\Veena Nigam\Desktop\SAS Documents\PROJECT";

/*Importing the Dataset*/

PROC IMPORT DATAFILE = "C:\Users\Veena Nigam\Desktop\SAS Documents\PROJECT\Telco Churn Data.csv"
            OUT = RIMA.TELECO
			DBMS = CSV;
			DATAROW = 2;
			GUESSINGROWS = 80000;
			GETNAMES = YES;
RUN;

/*Describing the properties of the project data*/

PROC CONTENTS DATA = RIMA.TELECO;
RUN;

/*Select Y(Churn) and Xs variables (Use Proc SQL)*/
PROC SQL;
 CREATE TABLE RIMA.PROJECT_VAR AS
 SELECT CustomerID,Churn,INPUT(MonthlyRevenue,BEST12.) AS MonthlyRevenue,INPUT(MonthlyMinutes,BEST12.) AS MonthlyMinutes,
		TotalRecurringCharge,Occupation,CreditRating,AdjustmentsToCreditRating,IncomeGroup,BlockedCalls, UnansweredCalls,
		OverageMinutes,ReceivedCalls,Droppedcalls,MonthsInService,CurrentEquipmentDays,	INPUT(AgeHH1,$2.) AS AgeHH1,
		INPUT(AgeHH2,$2.) AS AgeHH2, ChildrenInHH,Handsets,HandsetModels,RetentionCalls,NewCellphoneUser,MaritalStatus,
		MadeCallToRetentionTeam, RetentionOffersAccepted 
 FROM RIMA.TELECO
 WHERE CHURN NE "NA";
 QUIT;

/*CustomerID Churn MonthlyRevenue MonthlyMinutes TotalRecurringCharge DirectorAssistedCalls 
OverageMinutes RoamingCalls PercChangeMinutes PercChangeRevenues DroppedCalls BlockedCalls UnansweredCalls 
CustomerCareCalls ThreewayCalls ReceivedCalls OutboundCalls InboundCalls PeakCallsInOut OffPeakCallsInOut 
DroppedBlockedCalls CallForwardingCalls CallWaitingCalls MonthsInService UniqueSubs ActiveSubs ServiceArea Handsets
HandsetModels CurrentEquipmentDays AgeHH1 AgeHH2 ChildrenInHH HandsetRefurbished HandsetWebCapable TruckOwner RVOwner 
Homeownership BuysViaMailOrder RespondsToMailOffers OptOutMailings NonUSTravel OwnsComputer HasCreditCard RetentionCalls 
RetentionOffersAccepted NewCellphoneUser NotNewCellphoneUser ReferralsMadeBySubscriber IncomeGroup OwnsMotorcycle 
AdjustmentsToCreditRating HandsetPrice MadeCallToRetentionTeam CreditRating PrizmCode Occupation MaritalStatus*/


/*Missing Values Detection*/

/* create a format to group missing and nonmissing */

proc format;
 value $missfmt ' '='Missing' other='Not Missing';
 value  missfmt  . ='Missing' other='Not Missing';
run;
 
proc freq data= Rima.TELECO; 
format _CHAR_ $missfmt.; 
tables _CHAR_ / missing missprint nocum nopercent;
format _NUMERIC_ missfmt.;
tables _NUMERIC_ / missing missprint nocum nopercent;
run;



/*Missing Values Treatment (Either means or median)*/

PROC STDIZE DATA = RIMA.Teleco OUT= RIMA.TEL1 METHOD= MEAN REPONLY;
 VAR PercChangeRevenues MonthlyMinutes MonthlyRevenue TotalRecurringCharge DirectorAssistedCalls OverageMinutes
RoamingCalls PercChangeMinutes PercChangeRevenues;
RUN;

/*Checking if the missing values are replaced by mean value*/

PROC MEANS DATA = RIMA.PROJECT_NM_MEAN MAXDEC=2 N NMISS MIN MEAN STD MAX RANGE;
  VAR PercChangeRevenues MonthlyMinutes MonthlyRevenue TotalRecurringCharge DirectorAssistedCalls OverageMinutes
RoamingCalls PercChangeMinutes PercChangeRevenues;
RUN;

PROC SQL;
 CREATE TABLE RIMA.TEL_NEW AS
 SELECT *
 FROM RIMA.PROJECT_NM_MEAN
 WHERE CHURN NE 'NA';
 QUIT;

 PROC PRINT DATA=RIMA.TEL_NEW;
 RUN;

/*TAKING THE SAMPLE OUT OF THE DATASET*/

PROC SURVEYSELECT DATA=RIMA.TEL_NEW OUT= RIMA.TELECO_FINAL METHOD=SRS SAMPSIZE =30000 SEED= 987654321; 
RUN;

/*Checking the normality in distribution*/

%MACRO NORMAL(DATA = ,VARNAME=);
 PROC SGPLOT DATA = &DATA.;
 TITLE"DISTRIBUTION OF %UPCASE(&VARNAME.)";
 HISTOGRAM &VARNAME.;
 DENSITY &VARNAME.;
 RUN;
 %MEND NORMAL;

%NORMAL(DATA= , VARNAME= );
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= PERCCHANGEMINUTES);
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= PERCCHANGEREVENUES);
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= MONTHLYMINUTES);
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= MONTHLYREVENUE);
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= OVERAGEMINUTES);
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= ROAMINGCALLS);
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= TOTALRECURRINGCHARGE);
%NORMAL(DATA=RIMA.TELECO_FINAL, VARNAME= DIRECTORASSISTEDCALLS);


/*TREATING THE OUTLIERS*/

%MACRO OUTLIER (DATA= , VARNAME = );
 PROC MEANS DATA = &DATA. MAXDEC=2 N P25 P75 QRANGE;
 VAR &VARNAME.;
 RUN;
 PROC MEANS DATA = &DATA. MAXDEC = 2 N P25 P75 QRANGE;
 VAR &VARNAME.;
 OUTPUT OUT = RIMA.DEL P25 = Q1 P75 = Q3 QRANGE=IQR;
 RUN;

 DATA RIMA.TEMP1;
  SET RIMA.DEL ;
 LOWER_LIMIT = Q1 - (3*IQR);
 UPPER_LIMIT = Q1 + (3*IQR);
 RUN;
 PROC PRINT DATA = TEMP1;
 RUN;

/*CARTESIAN PRODUCT*/
  PROC SQL;
  CREATE TABLE RIMA.DATA_01 AS
  SELECT A.*,B.LOWER_LIMIT, B.UPPER_LIMIT
  FROM &DATA. AS A, RIMA.TEMP1 AS B
  ;
  QUIT;
  DATA RIMA.DATA_02;
  SET RIMA.DATA_01;
  IF &VARNAME. LE LOWER_LIMIT THEN &VARNAME._RANGE = "BELOW LOWER LIMIT";
  ELSE IF &VARNAME. GE UPPER_LIMIT THEN &VARNAME._RANGE = "ABOVE UPPER LIMIT";
  ELSE &VARNAME._RANGE = "WITHIN RANGE";
  RUN;
  QUIT;

/*PRINTING WITHIN RANGE DATA*/

  PROC SQL;
   CREATE TABLE RIMA.DATA_03 AS
   SELECT *
    FROM RIMA.DATA_02
	WHERE &VARNAME._RANGE = "WITHIN RANGE";
QUIT;
PROC PRINT DATA=RIMA.DATA_03;
RUN;

%MEND OUTLIER;


%OUTLIER(DATA= , VARNAME= );
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= PERCCHANGEMINUTES);
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= PERCCHANGEREVENUES);
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= MONTHLYMINUTES);
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= MONTHLYREVENUE);
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= OVERAGEMINUTES);
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= ROAMINGCALLS);
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= TOTALRECURRINGCHARGE);
%OUTLIER(DATA=RIMA.TELECO_FINAL, VARNAME= DIRECTORASSISTEDCALLS);

PROC MEANS DATA = RIMA.TELECO_FINAL MAXDEC = 2 N P25 P75 QRANGE;
 VAR DROPPEDCALLS;
OUTPUT OUT = RIMA.TEMP P25 = Q1 P75 = Q3 QRANGE=IQR;
RUN;

DATA RIMA.TEMP1;
 SET RIMA.TEMP;
 LOWER_LIMIT = Q1 - (3*IQR);
 UPPER_LIMIT = Q1 + (3*IQR);
 RUN;

 PROC PRINT DATA = RIMA.TEMP1;
 RUN;

/*CARTESIAN PRODUCT*/

 PROC SQL;
  CREATE TABLE RIMA.DATA_02 AS
  SELECT A.*,B.LOWER_LIMIT, B.UPPER_LIMIT
  FROM RIMA.TELECO_FINAL AS A, RIMA.TEMP1 AS B
  ;
  QUIT;

  PROC PRINT DATA = RIMA.DATA_02;
  RUN;


  DATA RIMA.DATA_03;
   SET RIMA.DATA_02;
IF DROPPEDCALLS LE LOWER_LIMIT THEN DROPPEDCALLS_RANGE = "BELOW LOWER LIMIT";
ELSE IF DROPPEDCALLS GE UPPER_LIMIT THEN DROPPEDCALLS_RANGE = "ABOVE UPPER LIMIT";
ELSE DROPPEDCALLS_RANGE = "WITHIN RANGE";
RUN;

PROC PRINT DATA= RIMA.DATA_03;
RUN;

PROC SQL;
 CREATE TABLE RIMA.DATA_DC AS
 SELECT *
 FROM RIMA.DATA_03
 WHERE DROPPEDCALLS_RANGE = "WITHIN RANGE";
 QUIT;

 PROC PRINT DATA = RIMA.DATA_04;
 RUN;



PROC SURVEYSELECT DATA=RIMA.DATA_04 OUT= RIMA.DATA_FINAL METHOD=SRS SAMPSIZE =29000 SEED= 987654321; 
RUN;

/*DATA TRANSFORMATION: CONTINUOUS TO CATEGORICAL VARIABLES*/

PROC MEANS DATA = RIMA.DATA_04 MAXDEC=1 N NMISS MIN MAX RANGE;
 VAR MONTHLYMINUTES;
RUN;

PROC FORMAT ; 
VALUE REV  LOW- 300 = "LOW"
		    301- 800 = "MEDIUM"
		 800- HIGH  = "HIGH";
RUN;


%LET DSN = RIMA.DATA_04;
%LET VAR1 = MONTHLYMINUTES;
%LET VAR2 = CHURN;

ODS PDF FILE = "C:\Users\Veena Nigam\Desktop\SAS Documents\PROJECT\IMAGES.PDF";
PROC FREQ DATA = &DSN;
TITLE "RELATIONSHIP BETWEEN &VAR1. AND &VAR2.";
 TABLE &VAR1. * &VAR2. /CHISQ NOROW NOCOL ;
 FORMAT &VAR1. REV.;
RUN;

PROC SGPLOT DATA = &DSN;
TITLE "RELATIONSHIP BETWEEN &VAR1. AND &VAR2.";
 VBAR &VAR1./ GROUP = &VAR2. ;
 FORMAT &VAR1. REV.;
RUN;
QUIT;
ODS PDF CLOSE;


/*UNIVARIATE ANALYSIS*/

ODS PDF FILE = "C:\Users\Veena Nigam\Desktop\SAS Documents\PROJECT\IMAGES.PDF";
PROC UNIVARIATE DATA = RIMA.Mr_03;
TITLE "COMPREHENSIVE UNIVARIATE ANALYSIS OF MONTHLY REVENUE ";
 VAR MonthlyRevenue;
RUN;

PROC GCHART DATA = RIMA.TEL_NEW;
  TITLE "DISTRIBUTION OF CHURN";
  PIE CHURN/ DISCRETE VALUE=OUTSIDE PERCENT = INSIDE;
  RUN;
  QUIT;

PROC SGPLOT DATA = RIMA.TELECO;
TITLE 'DISTRIBUTION OF TOTAL RECURRING CHARGE';
 HISTOGRAM TOTALRECURRINGCHARGE/FILLATTRS=(COLOR=RED)SCALE=PROPORTION;
 DENSITY TOTALRECURRINGCHARGE;
RUN;

PROC SGPLOT DATA = RIMA.TELECO;
TITLE 'DISTRIBUTION OF MONTHLY REVENUE';
 HISTOGRAM MONTHLYREVENUE/FILLATTRS=(COLOR=RED)SCALE=PROPORTION;
 DENSITY MONTHLYREVENUE;
RUN;


ODS PDF CLOSE;

PROC SQL;
 CREATE TABLE RIMA.TELECO AS
 SELECT *
 FROM RIMA.TELECO_FINAL
 WHERE MARITALSTATUS NE 'Unknown';
 QUIT;

/*BIVARIATE ANALYSIS*/
ODS PDF FILE = "C:\Users\Veena Nigam\Desktop\SAS Documents\PROJECT\IMAGES.PDF";

PROC SGPLOT DATA = RIMA.TELECO_FINAL;
TITLE'Customers with Dependents have lower churn rate';
 HBAR ChildrenInHH/GROUP = CHURN;
RUN;
QUIT;

PROC SGPLOT DATA = RIMA.TELECO;
TITLE'Customers with Dependents have lower churn rate';
 HBAR MARITALSTATUS/GROUP = CHURN;
 RUN;
QUIT;

proc sgplot data=RIMA.TELECO_FINAL;
TITLE 'EFFECT OF CREDIT RATING ON CHURN RATIO';
    vbar CreditRating/ response= AdjustmentsToCreditRating group=CHURN groupdisplay=cluster
                 datalabel datalabelattrs = (weight = bold) dataskin=gloss; yaxis grid;
run;

proc sgplot data=RIMA.TELECO_FINAL noautolegend;
   vbox CURRENTEQUIPMENTDAYS / category= occupation connect=mean connectattrs=(color=RED pattern=mediumdash thickness=1)
   meanattrs=(symbol=plus color=red size=20)lineattrs=(color=RED)medianattrs=(color=RED) whiskerattrs=(color=RED)
   outlierattrs=(color=green symbol=starfilled size=12); xaxis display=(noline noticks nolabel);
   yaxis display=(noline noticks) labelattrs=(weight=bold);
run;
title;

  PROC SQL;
   CREATE TABLE RIMA.SCATTER AS
   SELECT CustomerCareCalls,
          ThreewayCalls,
          DirectorAssistedCalls,
		  RoamingCalls,
		  Churn
  FROM RIMA.TEL_NEW
  ;
  QUIT;

  proc sgscatter data= rima.scatter;
matrix CustomerCareCalls ThreewayCalls DirectorAssistedCalls RoamingCalls/group=churn;
title "Matrix of scatter plots";
run;
title;

ods region row=3 column=2;
proc sgpanel data=rima.teleco_final;
    panelby churn;
    vbar handsetrefurbished / response=uniquesubs group= handsetwebcapable groupdisplay=cluster stat=mean;
    title "Churn Rate as per the Handset";
run;
title;

ODS PDF CLOSE;

/*Hypothesis Testing*/

/*HO : THERE IS NO DIFFERENCE
HA : THERE IS A DIFFERENCE*/

/*IF P<=0.05, THEN REJECT H0
*/
/*TTEST*/

PROC TTEST DATA= RIMA.TELECO_FINAL;
 PAIRED RetentionOffersAccepted*RetentionCalls;
RUN;


