//+---------------------------------------------------------------------------+
//|                                                  ChartSynchronization.mq4 |
//|                                                   Kilian19 @ ForexFactory |
//|                                                                           |
//| Copyright (c) 2015                                                        |
//|                                                                           |
//| Permission to use, copy, modify, and/or distribute this software for any  |
//| purpose with or without fee is hereby granted, provided that the above    |
//| copyright notice and this permission notice appear in all copies.         |
//|                                                                           |
//| THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES  |
//| WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF          |
//| MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR   |
//| ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES    |
//| WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN     |
//| ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF   |
//| OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.            |
//|                                                                           |
//+---------------------------------------------------------------------------+

#property copyright "Kilian19 @ ForexFactory"
#property link      "kilian19f@gmail.com"
#property version   "1.00"
#property strict
#property description "Quick and dirty chart alignment indicator."
#property description "This is an best effort approach due to the lack of certain mt4 functions we can only approximate the last visible bar on the screen."
#property description "Sometimes half bars will not be counted resulting in an offset of 1 or 2 bars. You might recieve better results by working with pixel values but the given accuracy is enough for me."
#property description "This was a 5 minute coding job. I have left some annotations behind in the code, feel free to improve it"
#property description "------------------------"
#property description "Adapted to MT5 by tony.smirnov@gmail.com in October 2020. Awesome work, @Kilian19!"
#property description "------------------------"
//it's not necessary to work with indicators. You can easily convert it into a script with a loop and do not loose functionality.
#property indicator_chart_window
#property indicator_buffers 0

// possible include you can play around with
//#include <Charts/Chart.mqh>

// I really am unhappy about how the code looks like and is organized but it's doing its job.

enum ChartSelection
  {
      ALL_CHARTS,
      SAME_CURRENCY,
      SAME_CURRENCY_AND_TF,
      SAME_TF
  };

input ChartSelection syncronize = SAME_CURRENCY;
input int NumberOfBarsShifted = 20; // How many bars to shift off right
   
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(){return(INIT_SUCCEEDED);}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],
                const double &close[],const long &tick_volume[],const long &volume[],const int &spread[]){
      return(rates_total);
}


 
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {

      
   
     //Catch all events which manipulate the chart position
      if(id == CHARTEVENT_CHART_CHANGE)
      {
         //Reference bar
         int firstBar = /* WindowFirstVisibleBar() */ ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR,0);
         
         //We want to aligh the charts on the right corner of the screen
         int lastVisibleBar = (int) (firstBar - ChartGetInteger(ChartID(),CHART_VISIBLE_BARS) + NumberOfBarsShifted);
           
         //If we are at the beginning do this check as you might get negative values.
         if(lastVisibleBar < 0)
            lastVisibleBar = 0;
         
         datetime lastVisibleBarTime = iTime(_Symbol,_Period,lastVisibleBar);
         //Alert(lastVisibleBarTime);
         
         // = 0 means we get the first bar in the Chart List
         long i = 0;
         while(i >= 0)
         {  
            
            Sleep(10);
            i = ChartNext(i);
             
            string chartSym = ChartSymbol(i);
            ENUM_TIMEFRAMES chartTF = ChartPeriod(i);
            
            //Filter settings. Disregard the charts which are not important. We could chace the resulst but this would not regard newly opened charts. 
            //If you want to do it properly you might want to create a chart list yourself and updated it reguarily in an on timer event.
            switch(syncronize)
            {
               case SAME_CURRENCY:
                  if(chartSym != Symbol())
                     continue;
                   break;
                  
               case SAME_TF:
                  if(chartTF != Period())
                     continue;
                   break;   
                  
               case SAME_CURRENCY_AND_TF:
               if(chartTF != Period() || chartSym != Symbol())
                     continue;
                  break;
            }
            
            //Disable auto scrolling.
            bool autoscroll = ChartGetInteger(i,CHART_AUTOSCROLL);
            if(autoscroll)
               ChartSetInteger(i,CHART_AUTOSCROLL,false);

            //we don't need to worry about our current chart
            if(i == ChartID())
               continue;
            
            int shift = iBarShift(chartSym,chartTF,lastVisibleBarTime, false);
            //ChartSetString(i,CHART_COMMENT,shift); // Sometimes chart jumps..
            
            if(shift >= 0)
            ChartNavigate(i,CHART_END,-shift);
            
            //ChartRedraw(i);
         }
      
      }
  }
//+------------------------------------------------------------------+
