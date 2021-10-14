//+------------------------------------------------------------------+
//|                                                           BB.mq5 |
//|                   Copyright 2009-2020, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "Lex"
#property link        ""
#property description "%B"
#include <MovingAverages.mqh>
//---
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  LightSkyBlue, DeepPink
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  YellowGreen, White, Red
#property indicator_style2  STYLE_DASH
#property indicator_label1  "Bands %B"
#property indicator_label2  "Bands %S"

color bbpColors[] = {clrLightSkyBlue, clrDeepPink};
color srColors[] = {clrYellowGreen, clrWhite, clrRed};

//--- input parametrs
input int      InpBandsPeriod=60;       // Period
input double   InpBandsDeviations=2.0;  // Deviation
input bool     InpSqueezeAlert = false;
input bool     InpBBAlert = false;
input bool     InpNotifyDevice = true;
input string   InpAlertPrefix = "M5";

//--- global variables
int            ExtBandsPeriod;
double         ExtBandsDeviations;
int            ExtPlotBegin=0;
//--- indicator buffer
double         ExtPercentBuffer[];
double         bbpColorBuffer[];

double         ExtSqueezeBuffer[];
double         srColorBuffer[];

double         ExtMLBuffer[];
double         ExtStdDevBuffer[];
//--- alert flag
bool           fBBSqueezed = false;
bool           fBBExpansion = false;
bool           fOverSell = false;
bool           fOverBuy  = false;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input values
   if(InpBandsPeriod<2)
     {
      ExtBandsPeriod=20;
      PrintFormat("Incorrect value for input variable InpBandsPeriod=%d. Indicator will use value=%d for calculations.",InpBandsPeriod,ExtBandsPeriod);
     }
   else
      ExtBandsPeriod=InpBandsPeriod;

   if(InpBandsDeviations==0.0)
     {
      ExtBandsDeviations=2.0;
      PrintFormat("Incorrect value for input variable InpBandsDeviations=%f. Indicator will use value=%f for calculations.",InpBandsDeviations,ExtBandsDeviations);
     }
   else
      ExtBandsDeviations=InpBandsDeviations;
//--- define buffers
   SetIndexBuffer(0, ExtPercentBuffer);
   SetIndexBuffer(1, bbpColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtSqueezeBuffer);
   SetIndexBuffer(3, srColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, ExtMLBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, ExtStdDevBuffer,INDICATOR_CALCULATIONS);

//--- set index labels
   PlotIndexSetString(0,PLOT_LABEL, "%B("+string(ExtBandsPeriod)+")");
   PlotIndexSetString(1,PLOT_LABEL, "%S("+string(ExtBandsPeriod)+")");
//--- indicator name
   IndicatorSetString(INDICATOR_SHORTNAME,"Bollinger %B");
//--- indexes draw begin settings
   ExtPlotBegin=ExtBandsPeriod-1;
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtBandsPeriod);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,ExtBandsPeriod);
//--- number of digits of indicator value
   IndicatorSetInteger(INDICATOR_DIGITS,3);

//--- Horizontal Lines of Oversell & Overbought
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.5);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, -0.5);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, 0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGoldenrod);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrGoldenrod);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 2, clrLightBlue);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 2, STYLE_SOLID);

//--- Setup Level Lines
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   //IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrPink);
   //IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_SOLID);

//--- Setup Colors for Plot
   //ChangeColors(0, bbpColors, ArraySize(bbpColors));
   //ChangeColors(1, srColors, ArraySize(srColors));
  }
//+------------------------------------------------------------------+
//| Bollinger Bands                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   if(rates_total<ExtPlotBegin)
      return(0);
//--- indexes draw begin settings, when we've recieved previous begin
   if(ExtPlotBegin!=ExtBandsPeriod+begin)
     {
      ExtPlotBegin=ExtBandsPeriod+begin;
      PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,ExtPlotBegin);
      PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,ExtPlotBegin);
     }
//--- starting calculation
   int pos;
   if(prev_calculated > 1)
      pos = prev_calculated - 1;
   else
      pos = 0;
//--- main cycle
   double BandWidth = 0;
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      //--- middle line
      ExtMLBuffer[i]=SimpleMA(i,ExtBandsPeriod,price);
      //--- calculate and write down StdDev
      ExtStdDevBuffer[i]=StdDev_Func(i,price,ExtMLBuffer,ExtBandsPeriod);
      //--- calculate percentage.
      BandWidth = ExtStdDevBuffer[i] * ExtBandsDeviations * 2;
      ExtPercentBuffer[i] = (price[i] - ExtMLBuffer[i]) / BandWidth;
      ExtSqueezeBuffer[i] = BandWidth / ExtMLBuffer[i] * 100;
      
      //--- coloring plots.
      bbpColorBuffer[i] = (MathAbs(ExtPercentBuffer[i]) >= 0.5 ? 1 : 0);
      srColorBuffer[i] = (ExtSqueezeBuffer[i] > 0.5 ? 1 : (ExtSqueezeBuffer[i] <= 0.1 ? 2 : 0));
     }
//--- OnCalculate done. Return new prev_calculated.

//--- Bollinger Band Squeeze Alert.
   double SqueezeRate = ExtSqueezeBuffer[rates_total - 1];

   string message;
   pos = rates_total - 1;
   
//--- BB Expansion.
   if(!fBBExpansion && SqueezeRate >= 0.5)
     {
      message = "[SR " + InpAlertPrefix + "] Volatile! " + SqueezeRate;
      if(InpSqueezeAlert && InpNotifyDevice)
         SendNotification(message);
      if(InpSqueezeAlert && !InpNotifyDevice)
         Alert(message);

      fBBExpansion = true;
     }
   if(fBBExpansion && SqueezeRate <= 0.45)
     {
      message = "[SR " + InpAlertPrefix + "] Volatile -> Calm. " + SqueezeRate;
      if(InpSqueezeAlert && InpNotifyDevice)
         SendNotification(message);
      if(InpSqueezeAlert && !InpNotifyDevice)
         Alert(message);

      fBBExpansion = false;
     }

//--- BB Squeezed
   if(!fBBSqueezed && SqueezeRate <= 0.1)
     {
      message = "[SR " + InpAlertPrefix + "] Squeezed! " + SqueezeRate;
      if(InpSqueezeAlert && InpNotifyDevice)
         SendNotification(message);
      if(InpSqueezeAlert && !InpNotifyDevice)
         Alert(message);

      fBBSqueezed = true;
     }
   if(fBBSqueezed && SqueezeRate >= 0.12)
     {
      message = "[SR " + InpAlertPrefix + "] Squeezed -> Calm. " + SqueezeRate;
      if(InpSqueezeAlert && InpNotifyDevice)
         SendNotification(message);
      if(InpSqueezeAlert && !InpNotifyDevice)
         Alert(message);

      fBBSqueezed = false;
     }


//--- Bollinger %B Over Sell / Buy Alerts.
   double PercentB = ExtPercentBuffer[rates_total - 1];

//--- Over Buy
   if(!fOverBuy && PercentB >= 0.5)
     {
      if(InpBBAlert && InpNotifyDevice)
         SendNotification("[BB " + InpAlertPrefix + "] Over BUY");
      if(InpBBAlert && !InpNotifyDevice)
         Alert("[BB Alert] Over BUY");

      fOverBuy = true;
     }
   if(fOverBuy && PercentB <= 0.45)
     {
      if(InpBBAlert && InpNotifyDevice)
         SendNotification("[BB " + InpAlertPrefix + "] O/B -> Normal");
      if(InpBBAlert && !InpNotifyDevice)
         Alert("[BB Alert] O/B -> Normal");

      fOverBuy = false;
     }

//--- Over Sell
   if(!fOverSell && PercentB <= -0.5)
     {
      if(InpBBAlert && InpNotifyDevice)
         SendNotification("[BB " + InpAlertPrefix + "] Over SELL");
      if(InpBBAlert && !InpNotifyDevice)
         Alert("[BB Alert] Over SELL");
      fOverSell = true;
     }
   if(fOverSell && PercentB >= -0.45)
     {
      if(InpBBAlert && InpNotifyDevice)
         SendNotification("[BB " + InpAlertPrefix + "] O/S -> Normal");
      if(InpBBAlert && !InpNotifyDevice)
         Alert("[BB Alert] O/S -> Normal");

      fOverSell = false;
     }

   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, PercentB);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, SqueezeRate);
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//+------------------------------------------------------------------+
double StdDev_Func(const int position,const double &price[],const double &ma_price[],const int period)
  {
   double std_dev=0.0;
//--- calcualte StdDev
   if(position>=period)
     {
      for(int i=0; i<period; i++)
         std_dev+=MathPow(price[position-i]-ma_price[position],2.0);
      std_dev=MathSqrt(std_dev/period);
     }
//--- return calculated value
   return(std_dev);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  ChangeColors(int plot_id, color &cols[], int plot_colors)
  {
   for(int i = 0; i < plot_colors; i ++)
      PlotIndexSetInteger(plot_id, PLOT_LINE_COLOR, i, cols[i]);
  }
//+------------------------------------------------------------------+
