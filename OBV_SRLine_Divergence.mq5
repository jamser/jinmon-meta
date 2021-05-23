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
int OBV_handle;

#define OBV_BUFFER_SIZE  60 * 12

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
   for (int offset = MaxLimit * BackTrackDays; offset > 0; offset -= MaxLimit)
      CalculateSRL(TotalBars, 0, offset);

//--- Create OBV Indicator.
   OBV_handle = iCustom(NULL, TimePeriod, "Examples\\OBV");

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

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
   PrintFormat("%d - %d", TotalBars, PreviousCalculatedBars);
   TotalBars = iBars(NULL, 0);
   if (TotalBars > PreviousCalculatedBars) {
      PreviousCalculatedBars = CalculateSRL(TotalBars, PreviousCalculatedBars, 0);
      PrintFormat("Calculate ... %d - %d", TotalBars, PreviousCalculatedBars);
      
      obvCount = CopyBuffer(OBV_handle, 0, 0, OBV_BUFFER_SIZE, obvValues);
      if (obvCount <= 0)
         PrintFormat("Copied OBV count = %d", obvCount);
      else
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
      TimePeriod = Period();

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
   int   Bars = iBars(NULL, 0);
   int   limit = MathMin(Bars - prev_calculated, MaxLimit);

   double dL = prLow(iLowest(NULL, TimePeriod, MODE_LOW, limit, offset));
   double dH = prHigh(iHighest(NULL, TimePeriod, MODE_HIGH, limit, offset));

   if(dL < dLNum || dHNum < dH)
     {
      int bufferSize = (MathMax(dHNum, dH) - MathMin(dLNum, dL)) * 10 + 1;
      
      ArrayResize(CrossBarsNum, bufferSize, 500);
      ArrayResize(CrossBarsMin, bufferSize, 500);
      
      if(dL < dLNum && dLNum != LOWEST_PRICE_INIT_VALUE)
        {
         int offset = int(dLNum - dL) * 10;
         for (int i = offset - 1; i >= 0; i --)
           {
            CrossBarsNum[i + offset] = CrossBarsNum[i];
            CrossBarsMin[i + offset] = CrossBarsMin[i];
           }
        }

      if (dL < dLNum)
         dLNum = dL;
      if (dHNum < dH)
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
void CheckDivergence()
  {
   
  }