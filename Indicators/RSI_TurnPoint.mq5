//+------------------------------------------------------------------+
//|                                                RSI_TurnPoint.mq5 |
//|                             Copyright 2021, Lex @ Jinmon Island. |
//+------------------------------------------------------------------+
#property copyright "Lex @ Jinmon Island"

//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_type1   DRAW_ARROW
#property indicator_type2   DRAW_ARROW
#property indicator_color1  Red
#property indicator_color2  DodgerBlue
#property indicator_label1  "Bearish Div."
#property indicator_label2  "Bullish Div."

#include <Indicators\Indicators.mqh>

CIndicators indicators;
CiRSI       *RSI;

//--- Indicators Parameters.
input long     InpCandleNumber = 5000;    // Number of Candles.
input int      InpRSIPeriod = 14;         // Period of Indicator.

//--- Pin Bar Parameters.
input bool     InpPinDiv = true;          // Detect Pin bar.
input double   InpPinRatio = 0.1;         // Pin Ratio.

//--- Engulfing Bar Parameters.
input bool     InpEngulfingDiv = true;    // Detect Engulfing bar.

//--- indicator buffers
double ExtBearishBuffer[];
double ExtBullishBuffer[];
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
   
//--- indicator buffers mapping
   SetIndexBuffer(0, ExtBearishBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ExtBullishBuffer, INDICATOR_DATA);
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
   if(rates_total < 3)
      return(0);

   int start;
//--- clean up arrays
   if(prev_calculated < 3)
     {
      start = 2;
      ArrayInitialize(ExtBearishBuffer, EMPTY_VALUE);
      ArrayInitialize(ExtBullishBuffer, EMPTY_VALUE);
     }
   else
      start = rates_total - 1;

//--- main cycle of calculations
   indicators.Refresh();

   double rsi1, rsi2 = RSI.Main(rates_total - start);
   double o, h, l, c;
   double op, hp, lp, cp;

   for(int i = start; i < rates_total && !IsStopped(); i ++)
     {
      o = open[i];
      h = high[i];
      l = low[i];
      c = close[i];

      rsi1 = rsi2;
      rsi2 = RSI.Main(rates_total - i - 1);
      
      if(InpPinDiv)
        {
         bool isPinBar = IsPinBar(o, h, l, c);
         
         //--- Bearish Div.
         if( high[i - 1] < high[i] && rsi1 > rsi2 && isPinBar )
           {
            ExtBearishBuffer[i] = high[i];
            ExtBullishBuffer[i] = EMPTY_VALUE;
            continue ;
           }
         else
            ExtBearishBuffer[i] = EMPTY_VALUE;
   
         //--- Bullish Div.
         if( low[i - 1] > low[i] && rsi1 < rsi2 && isPinBar )
           {
            ExtBullishBuffer[i] = low[i];
            ExtBearishBuffer[i] = EMPTY_VALUE;
            continue ;
           }
         else
            ExtBullishBuffer[i] = EMPTY_VALUE;
        }

      if(InpEngulfingDiv)
        {
         op = open[i - 1];
         hp = high[i - 1];
         lp = low[i - 1];
         cp = close[i - 1];
         
         if( IsBearishEngulfing(op, hp, lp, cp, o, h, l, c) && rsi1 > rsi2 )
           {
            ExtBearishBuffer[i] = high[i];
            continue ;
           }
         else
            ExtBearishBuffer[i] = EMPTY_VALUE;

         if( IsBullishEngulfing(op, hp, lp, cp, o, h, l, c) && rsi1 < rsi2 )
           {
            ExtBullishBuffer[i] = low[i];
            continue ;
           }
         else
            ExtBullishBuffer[i] = EMPTY_VALUE;
        }
     }

//--- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool IsPinBar(double open, double high, double low, double close)
  {
   return (InpPinRatio >= MathAbs( (open - close) / (high - low) ) );
  }

//+------------------------------------------------------------------+
bool IsBearishEngulfing(double o1, double h1, double l1, double c1, double o2, double h2, double l2, double c2)
  {
   return (c1 > o1 && o2 > c2 && l2 < l1 && h2 > h1 && (h2 - l2 > h1 - l1));
  }

//+------------------------------------------------------------------+
bool IsBullishEngulfing(double o1, double h1, double l1, double c1, double o2, double h2, double l2, double c2)
  {
   return (o1 > c1 && c2 >o2 && h2 > h1 && l2 > l1 && (h2 - l2 > h1 - l1));
  }  