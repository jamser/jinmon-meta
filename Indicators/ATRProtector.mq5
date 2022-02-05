//+------------------------------------------------------------------+
//|                                                 ATRProtector.mq5 |
//|                                                              Lex |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex"
#property link      ""
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 3
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_color1  Gold
#property indicator_type2   DRAW_LINE
#property indicator_color2  Gold
#property indicator_label1  "Top Margin"
#property indicator_label2  "Bottom Margin"

//--- input parametrs
input int      InpATRPeriod = 60;       // Period
input double   InpMultipler = 1;
input string   InpPrefix = "M1";
input bool     InpAlert = false;

//--- global variables
int         ExtPeriod;

//--- indicator buffer
double      TopMarginBuffer[];
double      BottomMarginBuffer[];
double      atrBuffer[];

// ATR Index
int         atrHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   if(InpATRPeriod < 10)
      ExtPeriod = 10;
   else
      ExtPeriod = InpATRPeriod;

   atrHandle = iATR(_Symbol, 0, ExtPeriod);

   SetIndexBuffer(0, TopMarginBuffer);
   SetIndexBuffer(1, BottomMarginBuffer);
   SetIndexBuffer(2, atrBuffer, INDICATOR_CALCULATIONS);

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
//--- Copy ATR Index from iATR
   int to_copy;
   if(prev_calculated > rates_total || prev_calculated < 0)
      to_copy = rates_total;
   else
     {
      to_copy = rates_total - prev_calculated;
      if(prev_calculated > 0)
         to_copy ++;
     }
   CopyBuffer(atrHandle, 0, 0, to_copy, atrBuffer);

//--- starting calculation
   int pos;
   if(prev_calculated > 2)
      pos = prev_calculated - 1;
   else
     {
      pos = 1;
      TopMarginBuffer[0] = 0;
      BottomMarginBuffer[0] = 0;
     }


//--- main cycle
   for(int i = pos; i < rates_total && !IsStopped(); i ++)
     {
      TopMarginBuffer[i] = high[i - 1] + atrBuffer[i] * InpMultipler;
      BottomMarginBuffer[i] = low[i - 1] - atrBuffer[i] * InpMultipler;
     }

   pos = rates_total - 1;
   if(InpAlert && high[pos] >= TopMarginBuffer[pos])
      SendNotification(InpPrefix + " breakout Top Margin (" + InpMultipler + ")");
   if(InpAlert && low[pos] <= BottomMarginBuffer[pos])
      SendNotification(InpPrefix + " breakout Bottom Margin (" + InpMultipler + ")");

   return(rates_total);
  }
//+------------------------------------------------------------------+
