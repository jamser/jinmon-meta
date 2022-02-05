//+------------------------------------------------------------------+
//|                                                    RSI_Diver.mq5 |
//|                             Copyright 2021, Lex @ Jinmon Island. |
//+------------------------------------------------------------------+
#property copyright "Lex @ Jinmon Island"

//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2
#property indicator_type1   DRAW_ARROW
#property indicator_type2   DRAW_ARROW
#property indicator_color1  Red
#property indicator_color2  DodgerBlue
#property indicator_label1  "Bearish Div."
#property indicator_label2  "Bullish Div."

#include <Generic\ArrayList.mqh>

#include "..\Experts\JinmonWilder04\CiASI.mqh"
#include <Indicators\Indicators.mqh>

CIndicators indicators;
CiRSI       *RSI;
CiASI       *ASI;

CArrayList<int>      hspIndex;
CArrayList<double>   hspValue;

CArrayList<int>      lspIndex;
CArrayList<double>   lspValue;

//--- Indicators Parameters.
input int      SP_RANGE = 36;             // Number of Candles to back track swing point.
input int      SP_SPAN = 10;
input long     InpCandleNumber = 5000;    // Number of Candles.
input int      InpRSIPeriod = 14;         // Period of Indicator.

//--- Pin Bar Parameters.
input bool     InpPinDiv = true;          // Detect Pin bar.
input double   InpPinRatio = 0.1;         // Pin Ratio.

//--- Engulfing Bar Parameters.
input bool     InpEngulfingDiv = true;    // Detect Engulfing bar.

//--- indicator buffers
double ExtSHSPBuffer[];
double ExtSLSPBuffer[];
double ExtHSPBuffer[];
double ExtLSPBuffer[];

//--- 10 pixels upper from high price
int    ExtArrowShift = -20;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
   MqlParam params[2];
   params[0].integer_value = InpRSIPeriod;
   params[0].type = TYPE_INT;
   params[1].integer_value = PRICE_CLOSE;
   params[1].type = TYPE_INT;
   RSI = indicators.Create(_Symbol, PERIOD_CURRENT, IND_RSI, 2, params);

   RSI.BufferResize(InpCandleNumber);

   ASI = new CiASI();
   ASI.Create(_Symbol, PERIOD_CURRENT, 300);
   ASI.BufferResize(InpCandleNumber);
   ASI.AddToChart(0, 1);
   indicators.Add(ASI);

//--- indicator buffers mapping
   SetIndexBuffer(0, ExtSHSPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtSLSPBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ExtHSPBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, ExtLSPBuffer, INDICATOR_CALCULATIONS);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
//--- sets first bar from what index will be drawn
   PlotIndexSetInteger(0, PLOT_ARROW, 218);
   PlotIndexSetInteger(1, PLOT_ARROW, 217);
//--- arrow shifts when drawing
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, ExtArrowShift);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -ExtArrowShift);
//--- sets drawing line empty value--
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
  }

void OnDeinit()
  {
   delete RSI;
   delete ASI;
  }

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
   if(rates_total < SP_RANGE)
      return(0);

   int start;
//--- clean up arrays
   if(prev_calculated == 0)
     {
      start = 0;
      ArrayInitialize(ExtSHSPBuffer, EMPTY_VALUE);
      ArrayInitialize(ExtSLSPBuffer, EMPTY_VALUE);
     }   
   else
      start = rates_total - SP_RANGE;

//--- main cycle of calculations
   indicators.Refresh();

   for(int i = start; i < rates_total && !IsStopped(); i ++)
     {
      double sp = ASI.SwingPoint(rates_total - i - 1);
        
      if(sp == 1)
        {
         ExtHSPBuffer[i] = high[i];
         ExtLSPBuffer[i] = EMPTY_VALUE;
        }
      if(sp == -1)
        {
         ExtHSPBuffer[i] = EMPTY_VALUE;
         ExtLSPBuffer[i] = low[i];
        }
          
      if(start % SP_SPAN == 0)
        {
         FindSignificantSwingPoint(high, low, start, rates_total, prev_calculated);
        }
     }

//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Finding HSP and LSP                                              |
//+------------------------------------------------------------------+
void FindSignificantSwingPoint(const double &high[],
                               const double &low[],
                               const int start,
                               const int rates_total,
                               const int prev_calculated)
  {
   int index, count;
   double sp0, sp1, sp2;

   hspIndex.Clear();
   hspValue.Clear();
   lspIndex.Clear();
   lspValue.Clear();

     {
      int i;
      //--- Find all HSP and LSP in range.
      for(i = start; i < ; i ++)
        {
         double sp = ASI.SwingPoint(i);
         if(sp == 1)
           {
            hspIndex.Add(i);
            hspValue.Add(ASI.Main(i));
           }
         else
            if(sp == -1)
              {
               lspIndex.Add(i);
               lspValue.Add(ASI.Main(i));
              }
        }
     }

//-- High Index SAR
   hspIndex.TryGetValue(0, index);
   hspValue.TryGetValue(0, sp0);
   HSARdatetime = iTime(_Symbol, TRADE_TF, index);
   HSARprice = iHigh(_Symbol, TRADE_TF, index);
   HSARvalue = sp0;

//-- Low Index SAR
   lspIndex.TryGetValue(0, index);
   lspValue.TryGetValue(0, sp0);
   LSARdatetime = iTime(_Symbol, TRADE_TF, index);
   LSARprice = iLow(_Symbol, TRADE_TF, index);
   LSARvalue = sp0;

//--- Find Significant HSP.
   count = hspIndex.Count();

   hspValue.TryGetValue(0, sp0);
   SHSPPrice = 0;
   HSPprice = 0;
   for(int i = 1; i < count - 1; i ++, sp0 = sp1)
     {
      hspValue.TryGetValue(i, sp1);
      hspValue.TryGetValue(i + 1, sp2);

      if(sp2 < sp1 && sp1 > sp0)
        {
         hspIndex.TryGetValue(i, SHSPIndex);
         SHSPDatetime = iTime(_Symbol, TRADE_TF, SHSPIndex);
         SHSPPrice = iHigh(_Symbol, TRADE_TF, SHSPIndex);
         SHSPValue = sp1;

         Print("Significant HSP time  : " + SHSPDatetime);
         Print("Significant HSP value : " + SHSPValue);
         Print("Significant HSP Price : " + SHSPPrice);

         hspIndex.TryGetValue(i - 1, index);
         HSPdatetime = iTime(_Symbol, TRADE_TF, index);
         HSPprice = iHigh(_Symbol, TRADE_TF, index);
         HSPvalue = sp0;
         break;
        }
     }

   if(SHSPPrice == 0)
      Print("No Significant HSP in range("+SP_RANGE+")");

//--- Find Significant LSP.
   count = lspIndex.Count();

   lspValue.TryGetValue(0, sp0);
   SLSPPrice = 0;
   LSPprice = 0;
   for(int i = 1; i < count - 1; i ++, sp0 = sp1)
     {
      lspValue.TryGetValue(i, sp1);
      lspValue.TryGetValue(i + 1, sp2);

      if(sp2 > sp1 && sp1 < sp0)
        {
         lspIndex.TryGetValue(i, SLSPIndex);
         SLSPDatetime = iTime(_Symbol, TRADE_TF, SLSPIndex);
         SLSPPrice = iLow(_Symbol, TRADE_TF, SLSPIndex);
         SLSPValue = sp1;

         Print("Significant LSP time  : " + SLSPDatetime);
         Print("Significant LSP value : " + SLSPValue);
         Print("Significant LSP Price : " + SLSPPrice);

         lspIndex.TryGetValue(i - 1, index);
         LSPdatetime = iTime(_Symbol, TRADE_TF, index);
         LSPprice = iLow(_Symbol, TRADE_TF, index);
         LSPvalue = sp0;
         break;
        }
     }

   if(SLSPPrice == 0)
      Print("No Significant LSP in range("+SP_RANGE+")");

  }