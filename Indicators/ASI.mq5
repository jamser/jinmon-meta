//+------------------------------------------------------------------+
//|                                                          ASI.mq5 |
//|                        Copyright 2009, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2009, MetaQuotes Software Corp."
#property link        "http://www.mql5.com"
#property description "Accumulation Swing Index"

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  LightSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_label1  "ASI"
//--- input parameter
input double InpT=300.0;      // T (maximum price changing)
//---- indicator buffers
double       ExtASIBuffer[];
double       ExtSPBuffer[];
double       ExtSIBuffer[];
double       ExtTRBuffer[];
//--- global variables
double       ExtTpoints,ExtT;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- check for input value
   if(fabs(InpT)>1e-7)
      ExtT=InpT;
   else
     {
      ExtT=300.0;
      printf("Input parameter T has wrong value. Indicator will use T = %f.",ExtT);
     }
//--- define buffers
   SetIndexBuffer(0,ExtASIBuffer);
   SetIndexBuffer(1,ExtSPBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,ExtSIBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,ExtTRBuffer,INDICATOR_CALCULATIONS);
//--- draw begin settings
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,1);
//--- number of digits of indicator value
   IndicatorSetInteger(INDICATOR_DIGITS,2);
//--- setup indicator level
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.5);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrWhiteSmoke);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
//--- calculate ExtTpoints value
   if(fabs(_Point)>1e-7)
      ExtTpoints=ExtT*_Point;
   else
      ExtTpoints=ExtT*pow(10,-_Digits);
//---- OnInit done
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const long &Volume[],
                const int &Spread[])
  {
//--- check for bars count
   if(rates_total<2) return(0);
//---
   int pos;
//--- start calculation
   pos=prev_calculated-1;
//--- correct position, when it's first iteration
   if(pos<=1)
     {
      pos=2;
      for(int i = 0; i < 2; i ++)
        {
         ExtASIBuffer[i]=0.0;
         ExtSPBuffer[i]=0;
         ExtSIBuffer[i]=0.0;
         ExtTRBuffer[i]=High[i]-Low[i];
        }
     }
//--- main cycle
   for(int i=pos;i<rates_total && !IsStopped();i++)
     {
      //--- get some data
      double dPrevClose=Close[i-1];
      double dPrevOpen=Open[i-1];
      double dClose=Close[i];
      double dHigh=High[i];
      double dLow=Low[i];
      //--- fill TR buffer
      ExtTRBuffer[i]=MathMax(dHigh,dPrevClose)-MathMin(dLow,dPrevClose);
      double ER=0.0;
      if(!(dPrevClose>=dLow && dPrevClose<=dHigh))
        {
         if(dPrevClose>dHigh) ER=MathAbs(dHigh-dPrevClose);
         if(dPrevClose<dLow)  ER=MathAbs(dLow-dPrevClose);
        }
      double K=MathMax(MathAbs(dHigh-dPrevClose),MathAbs(dLow-dPrevClose));
      double SH=MathAbs(dPrevClose-dPrevOpen);
      double R=ExtTRBuffer[i]-0.5*ER+0.25*SH;
      //--- calculate SI value
      if(R==0.0 || ExtTpoints==0.0) ExtSIBuffer[i]=0.0;
      else     ExtSIBuffer[i]=50*(dClose-dPrevClose+0.5*(dClose-Open[i])+
                              0.25*(dPrevClose-dPrevOpen))*(K/ExtTpoints)/R;
      //--- write down ASI buffer value
      ExtASIBuffer[i]=ExtASIBuffer[i-1]+ExtSIBuffer[i];
      
      //--- find High Swing Point and Low Swing Point.
      double asi2=ExtASIBuffer[i - 2];
      double asi1=ExtASIBuffer[i - 1];
      double asi0=ExtASIBuffer[i];
      //--- LSP
      if(asi2 > asi1 && asi1 < asi0)
         ExtSPBuffer[i - 1] = -1;
      //--- HSP
      else if (asi2 < asi1 && asi1 > asi0)
         ExtSPBuffer[i - 1] = 1;
      ExtSPBuffer[i] = 0;
     }
//--- update indicator level.
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, ExtASIBuffer[rates_total - 1]);
//---- OnCalculate done. Return new prev_calculated.
   return(rates_total);
  }
//+------------------------------------------------------------------+