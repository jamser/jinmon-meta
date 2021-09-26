//+------------------------------------------------------------------+
//|                                                       OBV_MA.mq5 |
//|                                                              Lex |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3
//--- plot OBV
#property indicator_label1  "OBV"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot FastMA
#property indicator_label2  "FastMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot SlowMA
#property indicator_label3  "SlowMA"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#include <MovingAverages.mqh>

//--- input parameters
input int      FastMALength=10;
input int      SlowMALength=30;
//--- indicator buffers
double         SlowMABuffer[];
double         FastMABuffer[];
double         OBVBuffer[];
//--- misc. variables
int   handle;
int   bars_calculated = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,OBVBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,FastMABuffer,INDICATOR_DATA);
   SetIndexBuffer(2,SlowMABuffer,INDICATOR_DATA);

   handle = iOBV(_Symbol, _Period, VOLUME_TICK);

   if(handle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the iOBV indicator for the symbol, code %d", GetLastError());
      return (INIT_FAILED);
     }

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   int values_to_copy;
   int calculated = BarsCalculated(handle);
   if(calculated <= 0)
     {
      PrintFormat("BarsCalculated() returned %d, error code %d",calculated,GetLastError());
      return(0);
     }

   if(prev_calculated == 0 || calculated != bars_calculated || rates_total > prev_calculated + 1)
     {
      //--- if the iOBVBuffer array is greater than the number of values in the iOBV indicator for symbol/period, then we don't copy everything
      //--- otherwise, we copy less than the size of indicator buffers
      if(calculated > rates_total)
         values_to_copy = rates_total;
      else
         values_to_copy = calculated;
     }
   else
     {
      //--- it means that it's not the first time of the indicator calculation, and since the last call of OnCalculate()
      //--- for calculation not more than one bar is added
      values_to_copy = (rates_total - prev_calculated) + 1;
     }

   if(CopyBuffer(handle, 0, 0, values_to_copy, OBVBuffer) < 0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iOBV indicator, error code %d",GetLastError());
      return(0);
     }

   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, SlowMALength, OBVBuffer, SlowMABuffer);
   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, FastMALength, OBVBuffer, FastMABuffer);

   bars_calculated = calculated;
   return(rates_total);
  }
//+------------------------------------------------------------------+
