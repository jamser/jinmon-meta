//+------------------------------------------------------------------+
//|                                        OBV_SRLine_Divergence.mq5 |
//|                                                              Lex |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Lex"
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Indicator management.
int TotalBars = 0;
int PreviousCalculatedBars = 0;
int OBVm1_handle;
int OBVm15_handle;
int ZigZag_handle;

#define OBV_BUFFER_SIZE  60 * 12 / 15

double obvValues[OBV_BUFFER_SIZE];
int obvCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);

//---
   InitSRLines();

   TotalBars = iBars(NULL, 0);
   for(int offset = MaxLimit * BackTrackDays; offset > 0; offset -= MaxLimit)
      CalculateSRL(TotalBars, 0, offset);

//--- Create OBV Indicator.
   OBVm1_handle = iOBV(NULL, PERIOD_M1, VOLUME_TICK);
   OBVm15_handle = iOBV(NULL, PERIOD_M15, VOLUME_TICK);
//--- Create ZigZag Indicator.
   ZigZag_handle = iCustom(NULL, PERIOD_M15, "Examples\\ZigZag");

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

   IndicatorRelease(OBVm1_handle);
   IndicatorRelease(OBVm15_handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
//PrintFormat("%d - %d", TotalBars, PreviousCalculatedBars);
   TotalBars = iBars(NULL, PERIOD_M1);
   if(TotalBars > PreviousCalculatedBars)
     {
      PreviousCalculatedBars = CalculateSRL(TotalBars, PreviousCalculatedBars, 0);
      //PrintFormat("Calculate ... %d - %d", TotalBars, PreviousCalculatedBars);

      CheckDivergence();
     }
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---

  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
//---

  }
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
//---

  }
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
//---

  }

//+------------------------------------------------------------------+
//| Calculate Support / Resistance Lines                             |
//+------------------------------------------------------------------+
extern int BackTrackDays = 5;
extern int MaxLimit = 1380;   // 23 Hrs in M1 timer frame.
extern int MaxCrossesLevel = 10;
extern double MaxR = 1;
extern color LineColor = White;
extern int LineWidth = 0;
extern int LineStyle = 0;
ENUM_TIMEFRAMES TimePeriod = 0;

color  Colors[] = {Red,Maroon,Sienna,OrangeRed,Purple,Indigo,DarkViolet,MediumBlue,DarkSlateGray};
int    Widths[] = {1,2,3,4,5,6,7,8,9};
string Alphabet[] = {"i","h","g","f","e","d","c","b","a"};

int CrossBarsNum[];
bool CrossBarsMin[];
double CrossBarsOBV[];

#define LOWEST_PRICE_INIT_VALUE  100000.0
double dLNum = LOWEST_PRICE_INIT_VALUE, dHNum = 0.0;

datetime TMaxI = 0;

#define MaxLines 1000
string LineName[MaxLines];
int LineIndex = 0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
double prLow(int i)
  {
   return (iLow(NULL, TimePeriod,i));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double prHigh(int i)
  {
   return (iHigh(NULL,TimePeriod,i));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Period2Int(int TmPeriod)
  {
   switch(TmPeriod)
     {
      case PERIOD_M1  :
         return(0);
      case PERIOD_M5  :
         return(1);
      case PERIOD_M15 :
         return(2);
      case PERIOD_M30 :
         return(3);
      case PERIOD_H1  :
         return(4);
      case PERIOD_H4  :
         return(5);
      case PERIOD_D1  :
         return(6);
      case PERIOD_W1  :
         return(7);
      case PERIOD_MN1 :
         return(8);
     }
   return (0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Period2AlpthabetString(int TmPeriod)
  {
   return (Alphabet[Period2Int(TmPeriod)]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitSRLines()
  {
//--- indicator buffers mapping
   if(TimePeriod == 0)
      TimePeriod = PERIOD_M1;

   if(TimePeriod != 0 && LineWidth == 0)
      if(Period2Int(TimePeriod) - Period2Int(Period()) >= 0)
         LineWidth = Widths[Period2Int(TimePeriod) - Period2Int(Period())];
      else
        {
         LineWidth = 0;
         if(LineStyle == 0)
            LineStyle = STYLE_DASH;
        }
   if(TimePeriod !=0 && LineColor == White)
      LineColor = Colors[Period2Int(TimePeriod)];


  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CalculateSRL(const int rates_total, const int prev_calculated, const int offset = 0)
  {
//---
   int   Bars = iBars(NULL, PERIOD_M1);
   int   limit = MathMin(Bars - prev_calculated, MaxLimit);

   double dL = prLow(iLowest(NULL, TimePeriod, MODE_LOW, limit, offset));
   double dH = prHigh(iHighest(NULL, TimePeriod, MODE_HIGH, limit, offset));

   if(dL < dLNum || dHNum < dH)
     {
      int bufferSize = (MathMax(dHNum, dH) - MathMin(dLNum, dL)) * 10 + 1;

      ArrayResize(CrossBarsNum, bufferSize, 500);
      ArrayResize(CrossBarsMin, bufferSize, 500);
      ArrayResize(CrossBarsOBV, bufferSize, 500);
      if(dL < dLNum && dLNum != LOWEST_PRICE_INIT_VALUE)
        {
         int offset = int(dLNum - dL) * 10;
         for(int i = offset - 1; i >= 0; i --)
           {
            CrossBarsNum[i + offset] = CrossBarsNum[i];
            CrossBarsMin[i + offset] = CrossBarsMin[i];
            CrossBarsOBV[i + offset] = CrossBarsOBV[i];
           }
        }

      if(dL < dLNum)
         dLNum = dL;
      if(dHNum < dH)
         dHNum = dH;
     }


   datetime Time = iTime(NULL, TimePeriod, limit + offset);

   for(double d = dL; d <= dH; d += 0.1)
     {
      int di = (d - dLNum) * 10;
      for(int i = 1 + offset; i < limit + offset; i ++)
         if(d > prLow(i) && d < prHigh(i))
            CrossBarsNum[di] ++;
      if(Time != TMaxI && TMaxI != 0)
         if(d > prLow(iBarShift(NULL,0,TMaxI))&& d < prHigh(iBarShift(NULL, 0, TMaxI)))
            CrossBarsNum[di] --;
     }
   TMaxI = Time;

   double l = MaxR * 10;
   for(double d = dL + MaxR + 0.1; d <= dH - MaxR - 0.1; d += 0.1)
     {
      int di = (d - dLNum) * 10;
      int MaxIndex = ArrayMaximum(CrossBarsNum, di - l, 2 * l);
      int MinIndex = ArrayMinimum(CrossBarsNum, di - l, 2 * l);

      if(!CrossBarsMin[di] && //CrossBarsNum[di]<MaxCrossesLevel&&
         CrossBarsNum[MaxIndex] - CrossBarsNum[MinIndex] > MaxCrossesLevel &&
         CrossBarsNum[di]     == CrossBarsNum[MinIndex] &&
         CrossBarsNum[di - 1] != CrossBarsNum[MinIndex])
        {
         CrossBarsMin[di] = true;
         LineName[LineIndex] = Period2AlpthabetString(TimePeriod) + TimePeriod + "_" + d;

         ObjectCreate(0, LineName[LineIndex], OBJ_HLINE, 0, 0, d);
         ObjectSetInteger(0, LineName[LineIndex], OBJPROP_COLOR, LineColor);
         ObjectSetInteger(0, LineName[LineIndex], OBJPROP_WIDTH, LineWidth);
         ObjectSetInteger(0, LineName[LineIndex], OBJPROP_STYLE, LineStyle);
         LineIndex ++;
        }

      if(CrossBarsMin[di] && CrossBarsNum[di] != CrossBarsNum[MinIndex])
        {
         CrossBarsMin[di] = false;
         ObjectDelete(0, Period2AlpthabetString(TimePeriod) + TimePeriod + "_" + d);
        }
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Divergence Verification Algorithms                               |
//+------------------------------------------------------------------+
//
enum DIVERGENCE_CHECK_STATE
  {
   NA_STATE = -1,
   HIT_SUPPORT_LINE = 0,
   UP_TREND_HIT_SUPPORT_LINE = 1,
   BACK_TO_SUPPORT_LINE = 2,
  };

//+------------------------------------------------------------------+
//| Identify Trend Up or Down                                        |
//+------------------------------------------------------------------+
int TrendDirection()
  {
   int dir = 1;
   double ZigZag[96];   // 12 Hrs.

   CopyBuffer(ZigZag_handle, 0, 0, 96, ZigZag);

//--- Find first point.
   int p1 = 95, p2;

   while(p1 >= 0 && ZigZag[p1] == 0)
      p1 --;
   p2 = p1 - 1;
   while(p2 >= 0 && ZigZag[p2] == 0)
      p2 --;

   if(ZigZag[p2] > ZigZag[p1])
      dir = -1;

   return dir;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime BuyTimeM15 = 0;
double BuySL = 0;

//---
double PrevSL1 = 0;
double PrevSL2 = 0;
datetime SLTime = 0;

DIVERGENCE_CHECK_STATE state = NA_STATE;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckDivergence()
  {
//--- No need to check since trend up.
   //if(TrendDirection() > 0)
   //   return ;

   if(BuyTimeM15 == iTime(NULL, PERIOD_M15, 0))
      return ;

//--- Expired SL Time.
   if(iBarShift(NULL, PERIOD_M15, SLTime) > 12)
     {
      SLTime = 0;
      PrevSL1 = 0;
      PrevSL2 = 0;
      state = NA_STATE;
     }
   
//--- Is M15 Pin bar cross any support line ?
   bool crossed = false;

   double dL = iLow(NULL, PERIOD_M15, 0);
   double dH = iHigh(NULL, PERIOD_M15, 0);
   double SL = 0.0;

   if(state != NA_STATE)
     {
      if(dH < PrevSL1)
        {
         state = NA_STATE;
         PrevSL1 = 0;
         PrevSL2 = 0;
         return ;
        }
     }

   for(double d = dL; d <= dH; d += 0.1)
     {
      int di = (d - dLNum) * 10;
      if(CrossBarsMin[di])
        {
         SL = di;
         SL = SL / 10 + dLNum;

         if(state == NA_STATE)
           {
            state = HIT_SUPPORT_LINE;
            PrevSL1 = SL;
            SLTime = iTime(NULL, PERIOD_M15, 0);
            return ;
           }
         if(state == HIT_SUPPORT_LINE)
           {
            if(SL < PrevSL1)
              {
               // Still falling, reset state !!!
               PrevSL1 = SL;
               SLTime = iTime(NULL, PERIOD_M15, 0);
              }

            if(PrevSL1 < SL)
              {
               state = UP_TREND_HIT_SUPPORT_LINE;
               PrevSL2 = SL;
              }
            return ;
           }
         if(state == UP_TREND_HIT_SUPPORT_LINE)
           {
            if(PrevSL2 <= SL)
              {
               // Going Up !
               PrevSL2 = SL;
               return ;
              }
            if(SL < PrevSL1)
              {
               // Still falling, reset state !!!
               state = HIT_SUPPORT_LINE;
               PrevSL1 = SL;
               SLTime = iTime(NULL, PERIOD_M15, 0);
               return ;
              }
            if(PrevSL1 < SL && SL < PrevSL2)
               return ;

            if(SL == PrevSL1)
              {
               state = BACK_TO_SUPPORT_LINE;
              }
           }

         crossed = true;
         break;
        }
     }

   if(!crossed)
      return ;

   if(SL == BuySL)
      return ;

   if(state != BACK_TO_SUPPORT_LINE)
     {
      Print("This Condition Should NOT be happend !!!");
      return ;
     }

//--- Back track to find point of comparison.
   int pins;
   int shift = iBarShift(NULL, PERIOD_M15, SLTime, true);

   pins = 0;
   for(int j = 0; j < 3; j ++)
      if(iLow(NULL, PERIOD_M15, shift + j) < SL && SL < iHigh(NULL, PERIOD_M15, shift + j))
         pins ++;

   if(pins >= 2)
     {
      obvCount = CopyBuffer(OBVm15_handle, 0, 0, OBV_BUFFER_SIZE, obvValues);
      if(obvCount <= 0)
         PrintFormat("Copied OBV count = %d", obvCount);
      else
         if(obvValues[OBV_BUFFER_SIZE - 1] > obvValues[OBV_BUFFER_SIZE - 1 - shift])
           {
            //--- Gotcha
            BuyTimeM15 = iTime(NULL, PERIOD_M15, 0);
            BuySL = PrevSL1;
            state = NA_STATE;
            PrevSL1 = 0;
            PrevSL2 = 0;

            datetime buyTime = iTime(NULL, PERIOD_M1, 0);
            PrintFormat("%s - Buy at %f - back : %d", TimeToString(buyTime, TIME_DATE|TIME_MINUTES), SL, shift);
           }
      // Job Done !!!
      return ;
     }
  }
//+------------------------------------------------------------------+
