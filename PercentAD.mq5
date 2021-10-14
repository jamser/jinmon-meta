//+------------------------------------------------------------------+
//|                                                    PercentAD.mq5 |
//|                                                              Lex |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex"
#property link      ""
#property version   "1.00"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  LightSeaGreen
#property indicator_label1  "A/D%"

//--- input params
input ENUM_APPLIED_VOLUME InpVolumeType=VOLUME_TICK; // Volume type
input int     InpPeriod=60;       // Period
//--- global variables
int      ExtPeriod;
//double   ExtPlotBegin = 0;
//--- indicator buffer
double ExtADbuffer[];
double ExtPercentBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input values
   if(InpPeriod < 2)
     {
      ExtPeriod = 10;
      PrintFormat("Incorrect value for input variable InpPeriod=%d. Indicator will use value=%d for calculations.",InpPeriod, ExtPeriod);
     }
   else
      ExtPeriod = InpPeriod;

//ExtPlotBegin = ExtPeriod - 1;

//--- index buffer
   SetIndexBuffer(0, ExtPercentBuffer);
   SetIndexBuffer(1, ExtADbuffer, INDICATOR_CALCULATIONS);
//--- indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "A/D%" );
//--- indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, 3);
//--- set index draw begin
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN,ExtPeriod);
//--- set index label
   PlotIndexSetString(0,PLOT_LABEL, "A/D%("+string(ExtPeriod)+")");
//--- Horizontal Line
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrPink);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_SOLID);
  }
//+------------------------------------------------------------------+
//| Accumulation/Distribution                                        |
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
//if(rates_total < ExtPlotBegin)
//   return(0);
//--- indexes draw begin settings, when we've recieved previous begin
//if(ExtPlotBegin != ExtBandsPeriod + begin)
//  {
//   ExtPlotBegin = ExtBandsPeriod + begin;
//   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPlotBegin);
//  }

//--- starting calculation
   int pos;
   if(prev_calculated > 1)
      pos = prev_calculated - 1;
   else
      pos = 0;

//--- main cycle
   for(int i=pos; i<rates_total && !IsStopped(); i++)
     {
      double h = high[i];
      double l = low[i];
      double o = open[i];
      double c = close[i];
      double ad = 0;

      if(h != l && c != o)
         ad = ((c - o) / (h - l)) * tick_volume[i];

      ExtADbuffer[i] = ad;

      if(ExtPeriod > 0 && ExtPeriod <= i + 1)
        {
         long total_volume = 0;
         double total_ad = 0;
         for(int x = 0; x < ExtPeriod; x ++)
           {
            total_volume += tick_volume[i - x];
            total_ad += ExtADbuffer[i - x];
           }
         ExtPercentBuffer[i] = total_ad / total_volume * 100;
        }
     }
//--- OnCalculate done. Return new prev_calculated.
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, ExtPercentBuffer[rates_total - 1]);
   return(rates_total);
  }
//+------------------------------------------------------------------+