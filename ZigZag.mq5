//+------------------------------------------------------------------+
//|                                                       ZigZag.mq5 |
//|                                                              Lex |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex"
#property link      ""
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Math\Stat\Normal.mqh>

//input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;

input long order_magic = 55555;

enum ORDER_CMD
  {
   SELL_ORDER = -1,
   NONE_ORDER = 0,
   BUY_ORDER = 1,
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionInfo position;
CTrade trade;

int MinHoldTime = 10 * 60;   // seconds
double OrderPrice = 0.0;
datetime OrderTime;
ORDER_CMD OrderType = NONE_ORDER;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong PlaceOrder(ORDER_CMD type, double volume, double price, int slippage, double stoploss, string comment)
  {
//--- MQL4
   /*
      OrderSend(Symbol(), cmd, volume, price, slippage, stoploss, takeprofit);
   */

//--- MQL5
   MqlTradeRequest request= {0};
   request.action = TRADE_ACTION_DEAL;
   request.magic = order_magic;
   request.symbol = _Symbol;
   request.type = (type == SELL_ORDER ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   request.volume = volume;
   request.deviation = slippage;
   request.sl = stoploss;
//request.tp = takeprofit;
   request.price = price;
   request.comment = comment;

   MqlTradeResult result = {0};
   if(trade.OrderSend(request, result))
     {
      OrderPrice = price;
      OrderTime = Time(0);
      OrderType = type;

      Print(__FUNCTION__,":",result.comment);
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CloseOrder(double volume)
  {
   if(PositionsTotal() == 0)
      return true;

   if(position.SelectByIndex(0))
      if(position.Symbol() == _Symbol)
         if(trade.PositionClose(position.Ticket()))
            return true;

   return false;
  }

//+------------------------------------------------------------------+
//| Order Management                                                 |
//+------------------------------------------------------------------+
int countBearish = 0;
int countBullish = 0;
int countBearishReversal = 0;
int countBullishReversal = 0;
int countCandidate = 0;

//--- input parameters
input double   lots=0.1;
double   tp=21 * 10 * _Point;
double   sl=5 * 10 * _Point;

double ORDER_MARGIN; // = tp*10*_Point * 1;

//--- Margin Protector
double _marginHigh[4];
double _marginLow[4];

bool IsMarginSafe(double price, int dir, double margin)
  {
   double high = 0, low = 0;
   //CopyHigh(_Symbol, PERIOD_M30, 0, 4, _marginHigh);
   //CopyLow(_Symbol, PERIOD_M30, 0, 4, _marginLow);
   
   //high = MathMean(_marginHigh);
   //low = MathMean(_marginLow);
   high = iHigh(_Symbol, PERIOD_H2, 1);
   low = iLow(_Symbol, PERIOD_H2, 1);
   
   if(dir == 1 &&
      high >= price + margin)
     {
      ORDER_MARGIN = margin;
      return true;
     }
      
   if(dir == -1 &&
      price - margin >= low)
     {
      ORDER_MARGIN = margin;
      return true;
     }

   return false;
  }


bool IsOrderOpen = false;
bool OrderPlaced = false;

//--- Price Action Recognition.
//---
int digit1=Digits();
int dig;

//--- Define wick size of Pin Bar.
const float PIN_RATIO = 1.6;
const float HOPPING_RATIO = -0.1;

//--- Inside Bar.
bool IsInsideBar(MqlRates& p, MqlRates& pp)
  {
   if((pp.high > p.high) &&
      (pp.low < p.low))
      return true;
   /*   if((p.close > p.open) &&
         (pp.open > pp.close) &&
         (pp.open > p.close) &&
         (p.open > pp.close))
         return true;

      if((p.open > p.close) &&
         (pp.close > pp.open) &&
         (pp.close > p.open) &&
         (p.close > pp.open))
         return true;
         */
   return false;
  }

//--- White Candle.
bool IsWhiteCandle(MqlRates& p)
  {
   if((p.close > p.open) &&
      (p.close - p.open) > (p.high - p.close) &&
      (p.close - p.open) > (p.open - p.low))
      return true;
   else
      return false;
  }

//--- Black Candle.
bool IsBlackCandle(MqlRates& p)
  {
   if((p.open > p.close) &&
      (p.open - p.close) > (p.high - p.open) &&
      (p.open - p.close) > (p.close - p.low))
      return true;
   else
      return false;
  }

//--- Doji
bool IsDoji(MqlRates& p)
  {
   if((p.close > p.open) &&
      (p.high - p.close) > (p.close - p.open) * PIN_RATIO &&
      (p.open - p.low) > (p.close - p.open) * PIN_RATIO)
      return true;
   else
      return false;
  }

//--- Ng Doji
bool IsNgDoji(MqlRates& p)
  {
   if((p.open > p.close) &&
      (p.high - p.open) > (p.open - p.close) * PIN_RATIO &&
      (p.close - p.low) > (p.open - p.close) * PIN_RATIO )
      return true;
   else
      return false;
  }

//--- Shooting Star.
bool IsShootingStar(MqlRates& p)
  {
   if((p.close > p.open) &&
      (p.high - p.close) > (p.close - p.open) * PIN_RATIO &&
      (p.close - p.open) > (p.open - p.low))
      return true;
   else
      return false;
  }

//--- Negative Shooting Star.
bool IsNgShootingStar(MqlRates& p)
  {
   if((p.open > p.close) &&
      (p.high - p.open) > (p.open - p.close) * PIN_RATIO &&
      (p.open - p.close) > (p.close - p.low))
      return true;
   else
      return false;
  }

//--- Hammer.
bool IsHammer(MqlRates& p)
  {
   if((p.close > p.open) &&
      (p.open - p.low) > (p.close - p.open) * PIN_RATIO &&
      (p.close - p.open) > (p.high - p.close))
      return true;
   else
      return false;
  }

//--- Negative Hammer.
bool IsNgHammer(MqlRates& p)
  {
   if((p.open > p.close) &&
      (p.close - p.low) > (p.open - p.close) * PIN_RATIO &&
      (p.open - p.close) > (p.high - p.open))
      return true;
   else
      return false;
  }

//--- Reject
bool IsRejected(MqlRates& p)
  {
   if(IsNgShootingStar(p) ||
      IsShootingStar(p) ||
      IsNgHammer(p) ||
      IsHammer(p) ||
      IsNgDoji(p) ||
      IsDoji(p))
      return true;
   else
      return false;
  }
//--- Bearish Engulfing.
bool IsBearishEngulfing(MqlRates& p, MqlRates& pp)
  {
   if((p.open > p.close) &&
      (pp.close > pp.open) &&
      (p.open >= pp.close) &&
      (pp.open > p.close) &&
// exclude pin bars.
      (p.open - p.close) > (p.high - p.open) &&
      (p.open - p.close) > (p.close - p.low) &&
      (pp.close - pp.open) > (pp.high - pp.close) &&
      (pp.close - pp.open) > (pp.open - pp.low))
      return true;
   else
      return false;
  }

//--- Bearish Doji.
bool IsBearishDoji(MqlRates& p, MqlRates& pp)
  {
   if(IsRejected(pp) && IsBlackCandle(p))
      return true;
   else
      return false;
  }

//--- Bearish Hopping.
bool IsBearishHopping(MqlRates& p, MqlRates& pp)
  {
   if(IsBlackCandle(p) &&
      IsBlackCandle(pp) &&
      pp.close - p.open > HOPPING_RATIO)
      return true;
   else
      return false;
  }


//--- Bullish Engulfing.
bool IsBullishEngulfing(MqlRates& p, MqlRates& pp)
  {
   if((p.close > p.open) &&
      (pp.open > pp.close) &&
      (p.open <= pp.close) &&
      (p.close > pp.open) &&
// exclude pin bar.
      (p.close - p.open) > (p.high - p.close) &&
      (p.close - p.open) > (p.open - p.low) &&
      (pp.open - pp.close) > (pp.high - pp.open) &&
      (pp.open - pp.close) > (pp.close - pp.low))
      return true;
   else
      return false;
  }

//--- Bullish Doji.
bool IsBullishDoji(MqlRates& p, MqlRates& pp)
  {
   if(IsRejected(pp) && IsWhiteCandle(p))
      return true;
   else
      return false;
  }

//--- Bullish Hopping.
bool IsBullishHopping(MqlRates& p, MqlRates& pp)
  {
   if(IsWhiteCandle(p) &&
      IsWhiteCandle(pp) &&
      p.open - pp.close >= HOPPING_RATIO )
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
const ENUM_TIMEFRAMES HighLevelTimeFrame = PERIOD_H1;

//+------------------------------------------------------------------+
//| Support and Resistance                                           |
//+------------------------------------------------------------------+
//---
int refIndex = -1;
bool refHit = false;
double Refs[100];
double targetRef;
//---
int MaxLimit = 72;
input int MaxCrossesLevel = 9;
double MaxR = 1;
ENUM_TIMEFRAMES TimeFrame = PERIOD_M15;
//---
int CrossBarsNum[];
bool CrossBarsMin[];
datetime Time[1000];

double d1Num =0.0, d2Num = 0.0;

datetime TMaxI = 0;

//---
double prLow(int i)
  {
   return (iLow(NULL,TimeFrame,i));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double prHigh(int i)
  {
   return (iHigh(NULL,TimeFrame,i));
  }

#define MaxLines 1000

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int FindLevel()
  {
//int    counted_bars=IndicatorCounted();
   int Bars = Bars(_Symbol, TimeFrame);
   int    limit = MathMin(Bars,MaxLimit);
   double d1 = prLow(iLowest(NULL,TimeFrame,MODE_LOW,limit,0));
   double d2 = prHigh(iHighest(NULL,TimeFrame,MODE_HIGH,limit,0));

   if(d1Num!=d1||d2Num!=d2)
     {
      ArrayResize(CrossBarsNum, (d2-d1)*10 + 1);
      ArrayResize(CrossBarsMin, (d2-d1)*10 + 1);
      if(d1Num != 0.0 && d1Num != d1)
        {
         ArrayCopy(CrossBarsNum,CrossBarsNum, 0, (d1Num-d1)*10 + 1);
         ArrayCopy(CrossBarsMin,CrossBarsMin, 0, (d1Num-d1)*10 + 1);
        }
      d1Num=d1;
      d2Num=d2;
     }

   int di;
   for(double d=d1; d<=d2; d+=0.1)
     {
      di = (d-d1)*10;
      CrossBarsNum[di] = 0;
      CrossBarsMin[di] = false;
     }

   for(double d=d1; d<=d2; d+=0.1)
     {
      int di = (d-d1)*10;
      for(int i=1; i<limit; i++)
         if(d>prLow(i)&&d<prHigh(i))
            CrossBarsNum[di]++;
     }

   double l=MaxR*10;
   int index = -1;
   for(double d = d1 + MaxR; d <= d2 - MaxR; d += 0.1)
     {
      int di = (d-d1)*10;

      if(!CrossBarsMin[di]&& //CrossBarsNum[di]<MaxCrossesLevel&&
         CrossBarsNum[ArrayMaximum(CrossBarsNum,2*l,di-l)]-CrossBarsNum[ArrayMinimum(CrossBarsNum,2*l,di-l)]>MaxCrossesLevel
         &&CrossBarsNum[di]  ==CrossBarsNum[ArrayMinimum(CrossBarsNum,2*l,di-l)]
         &&CrossBarsNum[di-1]!=CrossBarsNum[ArrayMinimum(CrossBarsNum,2*l,di-l)])
        {
         CrossBarsMin[di]=true;

         // set ref value.
         //PrintFormat("key level = %.2f", d);
         index ++;
         Refs[index] = d;
        }
     }

   return index;
  }
//---
void UpdateKeyLevels(int index)
  {
   if(index > -1)
     {
      int i;
      for(i = refIndex + 1; i <= index; i ++)
        {
         string id = "level-" + i;
         ObjectCreate(0,id,OBJ_HLINE,0,0,0);
         ObjectSetInteger(0,id,OBJPROP_COLOR,clrRed);
         ObjectSetInteger(0,id,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,id,OBJPROP_STYLE,STYLE_DASH);
        }

      for(i = index + 1; i <= refIndex; i ++)
        {
         ObjectDelete(0, "level-"+i);
        }

      for(i = 0; i <= index; i ++)
        {
         ObjectSetDouble(0,"level-"+i,OBJPROP_PRICE, Refs[i]);
        }

      refIndex = index;
      //PrintFormat("refs no. = %d", refIndex);
     }
  }

//+------------------------------------------------------------------+
//| ZigZag calculation                                               |
//+------------------------------------------------------------------+
// inputs
int InpDepth    = 3;  // Depth
int InpDeviation= 10;   // Deviation
int InpBackstep = 1;   // Back Step
// end of inputs.

double    ZigZagBuffer[];      // main buffer
double    HighMapBuffer[];     // ZigZag high extremes (peaks)
double    LowMapBuffer[];      // ZigZag low extremes (bottoms)

int       ExtRecalc=3;         // number of last extremes for recalculation

int zzIndexM1 = 0;
double zzPricesM1[7];
datetime zzTimesM1[7];

int zzIndexMh = 0;
double zzPricesMh[7];
datetime zzTimesMh[7];

int zzIndexMl = 0;
double zzPricesMl[7];
datetime zzTimesMl[7];

enum EnSearchMode
  {
   Extremum=0, // searching for the first extremum
   Peak=1,     // searching for the next ZigZag peak
   Bottom=-1   // searching for the next ZigZag bottom
  };

MqlRates m1Rates[];
MqlRates mhRates[];
MqlRates mlRates[];

const int SwingTimeSpan = 240;

ENUM_TIMEFRAMES zzTimeFrame = PERIOD_M1;
ENUM_TIMEFRAMES zzHighTimeFrame = PERIOD_M15;
ENUM_TIMEFRAMES zzLongTimeFrame = PERIOD_H1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(int shift)
  {
   return iTime(_Symbol, zzTimeFrame, shift);
  }
//+------------------------------------------------------------------+
//| Calculate ZigZag Lines for Swing High/Low Trading                |
//+------------------------------------------------------------------+
int CalculateZigZag(MqlRates& prices[], double& zzPrices[], datetime& zzTimes[])
  {
   int span = ArraySize(prices);
   if(ArraySize(prices) < span)
      return 0;

//---
   int    i=0;
   int    start = 0, extreme_search = Extremum, extreme_start;
   int    shift = 0, last_high_pos = 0,last_low_pos = 0, back;
   double val = 0, res = 0;
   double last_high = 0, last_low = 0;

//--- initializing
   ArrayInitialize(ZigZagBuffer,0.0);
   ArrayInitialize(HighMapBuffer,0.0);
   ArrayInitialize(LowMapBuffer,0.0);
   start = InpDepth;

   double pv = prices[span - 1].close;
   int dir = (prices[span - 2].close > pv ? 1 : -1);

//--- searching for high and low extremes
   for(shift = span - 2; shift >= 0; shift --)
     {
      val = prices[shift].close;
      if(dir == 1)
        {
         if(pv > val)
           {
            LowMapBuffer[shift] = val;
            dir = -1;
           }
         else
           {
            HighMapBuffer[shift] = val;
            HighMapBuffer[shift + 1] = 0;
           }
        }
      else
         if(dir == -1)
           {
            if(pv < val)
              {
               HighMapBuffer[shift] = val;
               dir = 1;
              }
            else
              {
               LowMapBuffer[shift] = val;
               LowMapBuffer[shift + 1] = 0;
              }
           }
      pv = val;
     }

//--- set last values
   last_low = 0.0;
   last_high = 0.0;

//--- final selection of extreme points for ZigZag
   for(shift = span - 1; shift >= 0; shift --)
     {
      res = 0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low == 0.0 && last_high == 0.0)
              {
               if(HighMapBuffer[shift] != 0)
                 {
                  last_high = prices[shift].close;
                  last_high_pos = shift;
                  extreme_search = Bottom;
                  ZigZagBuffer[shift] = last_high;
                  res = 1;
                  
                  extreme_start = shift;
                 }
               if(LowMapBuffer[shift] != 0.0)
                 {
                  last_low = prices[shift].close;
                  last_low_pos = shift;
                  extreme_search = Peak;
                  ZigZagBuffer[shift] = last_low;
                  res = 1;
                  
                  extreme_start = shift;
                 }
              }
            break;
         case Peak:
            if(HighMapBuffer[shift] != 0.0 && LowMapBuffer[shift] == 0.0)
              {
               val = HighMapBuffer[shift];

               if(val - last_low > InpDeviation * _Point ||
                  last_low_pos == extreme_start)
                 {
                  last_high = val;
                  last_high_pos = shift;
                  ZigZagBuffer[shift] = last_high;
                 }
               else
                 {
                  ZigZagBuffer[last_low_pos] = 0;
                  back = last_low_pos + 1;
                  while(back < span && ZigZagBuffer[back] == 0)
                     back ++;

                  if (back == span)
                     Print("Exception !!!");
                     
                  last_high = ZigZagBuffer[back];
                  last_high_pos = back;
                 }
               extreme_search = Bottom;
              }
            if(HighMapBuffer[shift] == 0.0 && LowMapBuffer[shift] != 0.0)
               Print("!!!!!!!!!!!!!!!! ERROR !!!!!!!!!!!!!!!");
            break;
         case Bottom:
            if(LowMapBuffer[shift] != 0.0 && HighMapBuffer[shift] == 0.0)
              {
               val = LowMapBuffer[shift];

               if(last_high - val > InpDeviation * _Point ||
                  last_high_pos == extreme_start)
                 {
                  last_low = val;
                  last_low_pos = shift;
                  ZigZagBuffer[shift] = last_low;
                 }
               else
                 {
                  ZigZagBuffer[last_high_pos] = 0;

                  back = last_high_pos + 1;
                  while (back < span && ZigZagBuffer[back] == 0)
                    back ++;

                  if (back == span)
                     Print("Exception !!!");

                  last_low = ZigZagBuffer[back];
                  last_low_pos = back;
                 }
               extreme_search = Peak;
              }
            if(HighMapBuffer[shift] != 0.0 && LowMapBuffer[shift] == 0.0)
               Print("!!!!!!!!!!!!!!!! ERROR !!!!!!!!!!!!!!!");
            break;
         default:
            return(0);
        }
     }

//Print("---- zz ----");
   for(i = 0, shift = 0; shift < span; shift ++)
     {
      // find out prices and times.
      if(ZigZagBuffer[shift] > 0 && i < 7)
        {
         zzPrices[i] = ZigZagBuffer[shift];
         zzTimes[i] = prices[shift].time;
         i ++;
         //Print(zzIndex + " P = ", ZigZagBuffer[shift], " : ", shift);
        }
     }
   return i;
  }
//+------------------------------------------------------------------+
void InitZigZagLines()
  {
   color lineColors[6] = { clrTomato, clrYellow, clrViolet, clrDodgerBlue, clrAqua, clrBlue };
   for(int i = 0; i < 6; i ++)
     {
      const string id = "zigzag-" + i;
      ObjectCreate(0, id, OBJ_TREND, 0, 0, 0);
      ObjectSetInteger(0, id, OBJPROP_COLOR, lineColors[i]);
      ObjectSetInteger(0, id, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, id, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
     }
  }
//+------------------------------------------------------------------+
//| Update ZigZag Lines.                                             |
//+------------------------------------------------------------------+
void UpdateZigZagLines()
  {
   int i;
   for(i = 0; i < zzIndexM1 - 1; i ++)
     {
      const string id = "zigzag-" + i;
      ObjectMove(0, id, 0, zzTimesM1[i], zzPricesM1[i]);
      ObjectMove(0, id, 1, zzTimesM1[i + 1], zzPricesM1[i + 1]);
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, false);
     }

   for(; i < 6; i ++)
     {
      const string id = "zigzag-" + i;
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
     }
  }
//+------------------------------------------------------------------+
//| Swigh-High Price Action Detector                                 |
//+------------------------------------------------------------------+
bool SwingHighPADetector(int type, string& message)
  {
   MqlRates prices[], p1, p2, p3, p4;
   ArraySetAsSeries(prices, true);

//--- 最新的K線還沒完成，略過，不參考．
   CopyRates(_Symbol, zzTimeFrame, 1, 4, prices);

   if(IsInsideBar(prices[0], prices[1]))
      return false;

   switch(type)
     {
      case 1:
         if(CheckHighLevelTrend() == TREND_LOW)
            return false;

         //--- 平穩上升：下方要有支撐。
         p1 = prices[0];
         //--- upside down hammer.
         if(IsNgShootingStar(p1))
           {
            // 如果之前是 Bearish Engulfing 那就不行！
            p2 = prices[1];
            p3 = prices[2];
            if(!IsBearishEngulfing(p2, p3))
               return true;
            else
               return false;
           }
         //--- hammer.
         if(IsHammer(p1))
            return true;

         break;
      case 2:
         //--- 牛直衝
         p1 = prices[0];
         p2 = prices[1];
         p3 = prices[2];
         p4 = prices[3];

         // Traps.
         if(IsBullishHopping(p3, p4) && IsBullishHopping(p2, p3))
            return false;

         if(IsBullishHopping(p3, p4) &&
            !IsBearishHopping(p1, p2) &&
            ( !IsRejected(p2) && !IsRejected(p1) )
            )
           {
            message = "Hopping";
            return true;
           }
         /*
         if(IsBullishEngulfing(p3, p4) && !IsBearishHopping(p1, p2) && !IsBearishDoji(p1, p2))
           {
            message = "Engulfing";
            return true;
           }
         if(IsBullishDoji(p3, p4) && !IsBullishHopping(p2, p3))
           {
            message = "Doji";
            return true;
           }
         */
         //  }
         break;
     }
   return false;
  }
//+------------------------------------------------------------------+
//| Swigh-Low Price Action Detector                                 |
//+------------------------------------------------------------------+
bool SwingLowPADetector(int type, string& message)
  {
   MqlRates prices[], p1, p2, p3, p4;
   ArraySetAsSeries(prices, true);

//--- 最新的K線還沒完成，略過，不參考．
   CopyRates(_Symbol, zzTimeFrame, 1, 4, prices);

   if(IsInsideBar(prices[0], prices[1]))
      return false;

   switch(type)
     {
      case 1:
         if(CheckHighLevelTrend() == TREND_HIGH)
            return false;

         //--- 平穩下降升：上方要有阻力。
         p1 = prices[0];
         //--- upside down hammer.
         if(IsHammer(p1))
           {
            // 如果之前是 Bullish Engulfing 那就不行！
            p2 = prices[1];
            p3 = prices[2];
            if(!IsBullishEngulfing(p2, p3))
               return true;
            else
               return false;
           }
         //--- negative shooting star.
         if(IsNgShootingStar(p1))
            return true;

         break;
      case 2:
         //--- 熊直落
         //if(CheckHighLevelTrend() == TREND_HIGH)
         //   return false;

         //for(int i = 0; i < 2; i ++)
         //  {
         p1 = prices[0];
         p2 = prices[1];
         p3 = prices[2];
         p4 = prices[3];

         // Traps.
         if(IsBearishHopping(p3, p4) && IsBearishHopping(p2, p3))
            return false;

         if(IsBearishHopping(p3, p4) &&
            !IsBullishHopping(p1, p2) &&
            ( !IsRejected(p2) && !IsRejected(p1) )
            )
           {
            message = "Hopping";
            return true;
           }
           
         /*
         if(IsBearishEngulfing(p3, p4) && !IsBullishHopping(p1, p2))
           {
            message = "Engulfing";
            return true;
           }
         if(IsBearishDoji(p3, p4) && !IsBearishHopping(p2, p3))
           {
            message = "Doji";
            return true;
           }
         */
         //  }
         break;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Reversal Price Action Detector                                 |
//+------------------------------------------------------------------+
bool ReversalPADetector(int type, string& message)
  {
   int i, pins;
   MqlRates prices[], p1, p2, p3, p4;
   ArraySetAsSeries(prices, true);

//--- 最新的K線還沒完成，略過，不參考．
   CopyRates(_Symbol, zzTimeFrame, 1, 4, prices);

   p1 = prices[0];
   p2 = prices[1];
   p3 = prices[2];
   p4 = prices[3];

// Pin bar: Rejected
   for(pins = 0, i = 0; i < 4; i ++)
     {
      if(IsRejected(prices[i]))
         pins ++;
     }
   if(pins >= 2)
     {
      message = "Pin Bar";
      return false;
     }

   switch(type)
     {
      case 1:
         //--- Pattern: Rejected.
         if(IsBullishHopping(p3, p4) &&
            ((IsRejected(p2) && IsBlackCandle(p1)) || (IsBlackCandle(p2) && IsRejected(p1)))
           )
           {
            message = "Hopping then Rejected";
            return false;
           }
         if(IsBullishEngulfing(p3, p4) &&
            ((IsRejected(p2) && IsBlackCandle(p1)) || (IsBlackCandle(p2) && IsRejected(p1)))
           )
           {
            message = "Bullish Engulfing then Rejected";
            return true;
           }

         //--- End of Rejected.
         /*
         if(IsBullishDoji(p3, p4) && IsBearishHopping(p1, p2))
           {
            message = "Doji Hopping";
            return true;
           }

         // Hopping
         if(IsBullishEngulfing(p3, p4) && IsBearishHopping(p1, p2))
           {
            message = "Engulfing + Bearish Hopping";
            return true;
           }
         if(IsBullishHopping(p3, p4) && IsBearishHopping(p1, p2))
           {
            message = "Hopping + Bearish Hopping";
            return true;
           }
         */
         break;
      case -1:
         //--- Pattern: Rejected.
         if(IsBearishHopping(p3, p4) &&
            ((IsRejected(p2) && IsWhiteCandle(p1)) || (IsWhiteCandle(p2) && IsRejected(p1)))
           )
           {
            message = "Hopping then Rejected";
            return false;
           }

         if(IsBearishEngulfing(p3, p4) &&
            ((IsRejected(p2) && IsWhiteCandle(p1)) || (IsWhiteCandle(p2) && IsRejected(p1)))
           )
           {
            message = "Bearish Engulfing then Rejected";
            return true;
           }
         //--- End of Rejected.
         /*
         if(IsBearishDoji(p3, p4) && IsBullishHopping(p1, p2))
           {
            message = "Doji Hopping";
            return true;
           }

         // Hopping
         if(IsBearishEngulfing(p3, p4) && IsBullishHopping(p1, p2))
           {
            message = "Engulfing + Bullish Hopping";
            return true;
           }
         if(IsBearishHopping(p3, p4) && IsBullishHopping(p1, p2))
           {
            message = "Hopping + Bullish Hopping";
            return true;
           }
         */
         break;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Swing High Trading                                               |
//+------------------------------------------------------------------+
bool CheckSwingHigh()
  {
   if(IsOrderOpen)
      return false;

   string message;
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double StopLoss;
   double delta = MathAbs(zzPricesM1[3] - zzPricesM1[0]);
      
//+------------------------------------------------------------------+
//|     牛市直衝                                                       |
//+------------------------------------------------------------------+
//|                           + 0                                    |
//|                          /                                       |
//|                         /                                        |
//|                    + 2 /                                         |
//|             + 4   / \ /                                          |
//|            / \   /   + 1                                         |
//|     + 6   /   \ /                                                |
//|      \   /     + 3                                               |
//|       \ /                                                        |
//|        + 5                                                       |
//+------------------------------------------------------------------+
   if(zzIndexM1 >= 4 &&
      //zzPricesM1[6] > zzPricesM1[5] &&
      zzPricesM1[4] > zzPricesM1[3] &&
      zzPricesM1[2] > zzPricesM1[1] &&

      zzPricesM1[0] > zzPricesM1[2] &&
      zzPricesM1[2] >= zzPricesM1[4] &&
      //zzPricesM1[4] >= zzPricesM1[6] &&

      zzPricesM1[1] > zzPricesM1[3] &&
      //zzPricesM1[3] > zzPricesM1[5] &&

      delta >= 1.5 && delta <= 3)
     {
      countCandidate ++;
      
      if(ReversalPADetector(1, message))
        {
         countBullishReversal ++;
         
         StopLoss = 2 * zzPricesM1[0] - zzPricesM1[3];
         if(StopLoss < Bid)
            return false;
            
         //if(IsMarginSafe(Bid, -1, tp))
            IsOrderOpen = PlaceOrder(SELL_ORDER,lots,Bid,5, StopLoss + sl, "Bullish -> Bearish - " + message);
         //else
         //   Print("Not enough Margin to place order!");
        }
      else
         if(SwingHighPADetector(2, message))
           {
            countBullish ++;

            StopLoss = zzPricesM1[3];
            if(StopLoss > Ask)
               return false;
               
            //if(IsMarginSafe(Ask, 1, tp))
               IsOrderOpen = PlaceOrder(BUY_ORDER,lots,Ask,5, StopLoss - sl, "Bullish In - " + message);
            //else
            //   Print("Not enough Margin to place order!");
           }

      if(IsOrderOpen)
         return true;
     }

//+------------------------------------------------------------------+
//|     平穩上升                                                      |
//+------------------------------------------------------------------+
//|                   + 1                                            |
//|                  / \                                             |
//|                 /   + 0                                          |
//|            + 3 /                                                 |
//|       + 5 / \ /                                                  |
//|      / \ /   + 2                                                 |
//|     /   + 4                                                      |
//+------------------------------------------------------------------+
   if(zzIndexM1 >= 5 &&
      zzPricesM1[5] > zzPricesM1[4] &&
      zzPricesM1[3] > zzPricesM1[2] &&
      zzPricesM1[1] > zzPricesM1[0] &&


      zzPricesM1[2] > zzPricesM1[4] &&
      zzPricesM1[3] >= zzPricesM1[5] &&

      zzPricesM1[1] > zzPricesM1[3] &&
      zzPricesM1[0] > zzPricesM1[3] &&

      MathAbs(zzPricesM1[4] - zzPricesM1[1]) >= 1.5 &&
      SwingHighPADetector(1, message))
     {
      //IsOrderOpen = PlaceOrder(BUY_ORDER,lots,Ask,5,zzPricesM1[2] - (sl*10*_Point));
      if(IsOrderOpen)
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Swing High Trading                                               |
//+------------------------------------------------------------------+
bool CheckSwingLow()
  {
   if(IsOrderOpen)
      return false;

   string message;
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double StopLoss;
   double delta = MathAbs(zzPricesM1[3] - zzPricesM1[0]);
   
//+------------------------------------------------------------------+
//|     熊市直落                                                       |
//+------------------------------------------------------------------+
//|      + 5                                                         |
//|     / \                                                          |
//|    /   \     + 3                                                 |
//|   + 6   \   / \                                                  |
//|          \ /   \   + 1                                           |
//|           + 4   \ / \                                            |
//|                  + 2 \                                           |
//|                       \                                          |
//|                        \                                         |
//|                         + 0                                      |
//+------------------------------------------------------------------+
   if(zzIndexM1 >= 4 &&
      //zzPricesM1[6] < zzPricesM1[5] &&
      zzPricesM1[4] < zzPricesM1[3] &&
      zzPricesM1[2] < zzPricesM1[1] &&

      zzPricesM1[0] < zzPricesM1[2] &&
      zzPricesM1[2] <= zzPricesM1[4] &&
      //zzPricesM1[4] <= zzPricesM1[6] &&

      zzPricesM1[1] < zzPricesM1[3] &&
      //zzPricesM1[3] < zzPricesM1[5] &&

      delta >= 1.5 && delta <= 3)
     {
      countCandidate ++;
      
      if(ReversalPADetector(-1, message))
        {
         countBearishReversal ++;
         
         StopLoss = 2 * zzPricesM1[0] - zzPricesM1[3];
         if(StopLoss > Ask)
            return false;
         
         //if(IsMarginSafe(Ask, 1, tp))
            IsOrderOpen = PlaceOrder(BUY_ORDER,lots,Ask,5, StopLoss - sl, "Bearish -> Bullish - " + message);
         //else
         //   Print("Not enough Margin to place order!");
        }
      else
         if(SwingLowPADetector(2, message))
           {
            countBearish ++;
            
            StopLoss = zzPricesM1[3];
            if(StopLoss < Bid)
               return false;
            
            //if(IsMarginSafe(Bid, -1, tp))
               IsOrderOpen = PlaceOrder(SELL_ORDER,lots,Bid,5, StopLoss + sl, "Bearish In - " + message);
            //else
            //   Print("Not enough Margin to place order!");
           }

      if(IsOrderOpen)
         return true;
     }

//+------------------------------------------------------------------+
//|     平穩下降                                                      |
//+------------------------------------------------------------------+
//|     \   + 4                                                      |
//|      \ / \   + 2                                                 |
//|       + 5 \ / \                                                  |
//|            + 3 \                                                 |
//|                 \   + 0                                          |
//|                  \ /                                             |
//|                   + 1                                            |
//+------------------------------------------------------------------+
   if(zzIndexM1 >= 5 &&
      zzPricesM1[5] < zzPricesM1[4] &&
      zzPricesM1[3] < zzPricesM1[2] &&
      zzPricesM1[1] < zzPricesM1[0] &&

      zzPricesM1[2] <= zzPricesM1[4] &&
      zzPricesM1[3] < zzPricesM1[5] &&

      zzPricesM1[1] < zzPricesM1[3] &&
      zzPricesM1[0] < zzPricesM1[3] &&
      MathAbs(zzPricesM1[4] - zzPricesM1[1]) >= 1.5 &&
      SwingLowPADetector(1, message))
     {
      //IsOrderOpen = PlaceOrder(SELL_ORDER,lots,Bid,5,zzPricesM1[2] + (sl*10*_Point));
      if(IsOrderOpen)
         return true;
     }

   return false;
  }

//+-----------------------------------------------------------------s-+
//| Swing High Trading                                               |
//+------------------------------------------------------------------+
enum HIGH_LEVEL_TREND
  {
   TREND_CONSOLIDATED = 2,
   TREND_HIGH = 1,
   TREND_NONE = 0,
   TREND_LOW = -1,
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
HIGH_LEVEL_TREND CheckHighLevelTrend()
  {

//+------------------------------------------------------------------+
//|          Consolidation                                           |
//+------------------------------------------------------------------+
//if(zzPricesM1)

//+------------------------------------------------------------------+
//|          Trend High                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|     牛市直衝                                                       |
//+------------------------------------------------------------------+
//|                           + 0                                    |
//|                          /                                       |
//|                         /                                        |
//|                    + 2 /                                         |
//|             + 4   / \ /                                          |
//|            / \   /   + 1                                         |
//|     + 6   /   \ /                                                |
//|      \   /     + 3                                               |
//|       \ /                                                        |
//|        + 5                                                       |
//+------------------------------------------------------------------+
   if(zzIndexMh >= 4 &&
      //zzPricesMh[6] > zzPricesMh[5] &&
      zzPricesMh[4] > zzPricesMh[3] &&
      zzPricesMh[2] > zzPricesMh[1] &&

      zzPricesMh[0] > zzPricesMh[2] &&
      zzPricesMh[2] >= zzPricesMh[4] &&
      //zzPricesMh[4] >= zzPricesMh[6] &&

      zzPricesMh[1] > zzPricesMh[3])
      //zzPricesMh[1] > zzPricesMh[3] &&
      //zzPricesMh[3] > zzPricesMh[5])
      return TREND_HIGH;

//+------------------------------------------------------------------+
//|     平穩上升                                                      |
//+------------------------------------------------------------------+
//|                   + 1                                            |
//|                  / \                                             |
//|                 /   + 0                                          |
//|            + 3 /                                                 |
//|       + 5 / \ /                                                  |
//|      / \ /   + 2                                                 |
//|     /   + 4                                                      |
//+------------------------------------------------------------------+
   if(zzIndexMh >= 5 &&
      zzPricesMh[5] > zzPricesMh[4] &&
      zzPricesMh[3] > zzPricesMh[2] &&
      zzPricesMh[1] > zzPricesMh[0] &&

      zzPricesMh[2] > zzPricesMh[4] &&

      zzPricesMh[1] > zzPricesMh[3] &&
      zzPricesMh[0] > zzPricesMh[3] &&

      zzPricesMh[3] >= zzPricesMh[5])
      return TREND_NONE;


//+------------------------------------------------------------------+
//|          Trend Low                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|     熊市直落                                                       |
//+------------------------------------------------------------------+
//|      + 5                                                         |
//|     / \                                                          |
//|    /   \     + 3                                                 |
//|   + 6   \   / \                                                  |
//|          \ /   \   + 1                                           |
//|           + 4   \ / \                                            |
//|                  + 2 \                                           |
//|                       \                                          |
//|                        \                                         |
//|                         + 0                                      |
//+------------------------------------------------------------------+
   if(zzIndexMh >= 4 &&
      //zzPricesMh[6] < zzPricesMh[5] &&
      zzPricesMh[4] < zzPricesMh[3] &&
      zzPricesMh[2] < zzPricesMh[1] &&

      zzPricesMh[0] < zzPricesMh[2] &&
      zzPricesMh[2] <= zzPricesMh[4] &&
      //zzPricesMh[4] <= zzPricesMh[6] &&

      zzPricesMh[1] < zzPricesMh[3])
      //zzPricesMh[1] < zzPricesMh[3] &&
      //zzPricesMh[3] < zzPricesMh[5])
      return TREND_LOW;

//+------------------------------------------------------------------+
//|     平穩下降                                                      |
//+------------------------------------------------------------------+
//|     \   + 4                                                      |
//|      \ / \   + 2                                                 |
//|       + 5 \ / \                                                  |
//|            + 3 \                                                 |
//|                 \   + 0                                          |
//|                  \ /                                             |
//|                   + 1                                            |
//+------------------------------------------------------------------+
   if(zzIndexMh >= 5 &&
      zzPricesMh[5] < zzPricesMh[4] &&
      zzPricesMh[3] < zzPricesMh[2] &&
      zzPricesMh[1] < zzPricesMh[0] &&

      zzPricesMh[2] < zzPricesMh[4] &&

      zzPricesMh[1] < zzPricesMh[3] &&
      zzPricesMh[0] < zzPricesMh[3] &&

      zzPricesMh[3] <= zzPricesMh[5])
      return TREND_NONE;

   return TREND_NONE;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);

//---
   ArrayResize(ZigZagBuffer, SwingTimeSpan);
   ArrayResize(LowMapBuffer, SwingTimeSpan);
   ArrayResize(HighMapBuffer, SwingTimeSpan);

//--- create zigzag lines.
   InitZigZagLines();

//--- Init ZigZag Lines Data.
   ArraySetAsSeries(m1Rates, true);
   ArraySetAsSeries(mhRates, true);
   ArraySetAsSeries(mlRates, true);

   ArrayResize(m1Rates, SwingTimeSpan);
   ArrayResize(mhRates, SwingTimeSpan / 4);
   ArrayResize(mlRates, SwingTimeSpan / 4);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

   Print("\n\nBearish count: ", countBearish);
   Print("Bearish R count: ", countBearishReversal);
   Print("Bullish count: ", countBullish);
   Print("Bullish R count: ", countBullishReversal);
   Print("\n\nCandidate count: ", countCandidate);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   string message;

   if(OrderPlaced && (Time(0) - OrderTime) > MinHoldTime)
     {
      dig=digit1-1;
      //---- Candle1 OHLC
      MqlRates prices[], p, pp, ppp;
      ArraySetAsSeries(prices, true);
      CopyRates(_Symbol, zzTimeFrame, 0, 3, prices);

      p = prices[0];
      pp = prices[1];
      ppp = prices[2];

      bool closeOrder = false;

      if(!refHit)
        {
         double ref;
         for(int i = 0; i <= refIndex; i ++)
           {
            ref = Refs[i];
            if((p.high == ref) ||
               (p.low == ref) ||
               ((p.high > ref) && (p.low < ref)) ||
               ((pp.low < ref) && (p.high >= ref)) |
               ((pp.high > ref) && (p.high <= ref)))
              {
               refHit = true;
               targetRef = ref;
               PrintFormat("Hit Price %.2f", targetRef);
              }
           }
        }
      // Close price must greater than order price.
      if(refHit)
        {
         // Hit Support.
         if(OrderType == BUY_ORDER)
           {
            if(OrderPrice > targetRef)
              {
               refHit = false;
               return ;
              }
            // Hit Resistance.
            else
               closeOrder = true;
           }
         if(OrderType == SELL_ORDER)
           {
            if(OrderPrice < targetRef)
              {
               refHit = false;
               return ;
              }
            // Hit Support.
            else
               closeOrder = true;
           }
         if(OrderType == NONE_ORDER)
           {
            refHit = false;
            return ;
           }
        }

      // Protect profits for LONG.
      if(OrderType == BUY_ORDER && p.close > OrderPrice + ORDER_MARGIN)
        {

         //---- Pattern 1 - bearish doji
         /*
         if(IsBearishDoji(pp, ppp))
           {
            Print("Bearish Doji");
            closeOrder = true;
            refHit = false;
           }

         //---- Pattern 3 - bearish
         if(IsBearishHopping(pp, ppp))
           {
            Print("Bearish Hopping");
            closeOrder = true;
            refHit = false;
           }

         //---- Bullish Engulfing candle.
         if(IsBearishEngulfing(pp, ppp))
           {
            closeOrder = true;
            refHit = false;
            Print("Bearish Engulfing candle");
           }
           */
         if(ReversalPADetector(1, message))
           {
            closeOrder = true;
            refHit = false;
            Print("Bullish -> Bearish - ", message);
           }
           
         //---- Stand above Resistance.
         if(p.low >= targetRef &&
            pp.low >= targetRef &&
            ppp.low >= targetRef)
           {
            refHit = false;
            //PrintFormat("Overcoming Resistance %.2f", targetRef);
           }
        }

      // Protect profits for SHORT.
      if(OrderType == SELL_ORDER && p.close < OrderPrice - ORDER_MARGIN)
        {

         //---- Pattern 1 - bearish
         /*
         if(IsBullishDoji(pp, ppp))
           {
            Print("Bullish Doji");
            closeOrder = true;
            refHit = false;
           }

         //---- Pattern 3 - bearish
         if(IsBullishHopping(pp, ppp))
           {
            Print("Bullish Hopping");
            closeOrder = true;
            refHit = false;
           }

         //---- Bullish Engulfing candle.
         if(IsBullishEngulfing(pp, ppp))
           {
            closeOrder = true;
            refHit = false;
            Print("Bullish Engulfing candle");
           }
           */
         if(ReversalPADetector(-1, message))
           {
            closeOrder = true;
            refHit = false;
            Print("Bearish -> Bullish - ", message);
           }

         //---- Drop below Support.
         if(p.high <= targetRef &&
            pp.high <= targetRef &&
            ppp.high <= targetRef)
           {
            refHit = false;
            //PrintFormat("Overcoming Resistance %.2f", targetRef);
           }
        }

      //--- Close position while bearish.
      if(closeOrder)
        {
         if(CloseOrder(lots))
           {
            IsOrderOpen = false;
            OrderPlaced = false;
            if(refHit)
              {
               refHit = false;
               Print("Hit Resistance & Take Profit !!!");
              }
            else
               Print("Close Position to protect profits!");
           }
         else
            Print("Failed to close position!!!");
        }   //--- End of Close position.
     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+

const int BULLISH = 1;
const int BEARISH = -1;

int HighLevelZZ = 5;
//---
void OnTimer()
  {
   int n = FindLevel();
   UpdateKeyLevels(n);

   CopyRates(_Symbol, zzTimeFrame, 3, SwingTimeSpan, m1Rates);
   zzIndexM1 = CalculateZigZag(m1Rates, zzPricesM1, zzTimesM1);
   UpdateZigZagLines();

   CopyRates(_Symbol, zzHighTimeFrame, 1, SwingTimeSpan / 4, mhRates);
   zzIndexMh = CalculateZigZag(mhRates, zzPricesMh, zzTimesMh);

   CopyRates(_Symbol, zzLongTimeFrame, 1, SwingTimeSpan / 4, mlRates);
   zzIndexMl = CalculateZigZag(mlRates, zzPricesMl, zzTimesMl);

// is time to place order ?
   if(!IsOrderOpen)
     {
      HIGH_LEVEL_TREND  trend = CheckHighLevelTrend();
      //if (trend == TREND_HIGH)
      //
      //if (trend == TREND_LOW)
      if(zzPricesMl[0] > zzPricesMl[1])
         CheckSwingHigh();
      else
         CheckSwingLow();
     }

//--- Handle order.
   if(OrderPlaced == true)
     {
      if(PositionsTotal() == 0)
        {
         Print("Order Closed");
         IsOrderOpen = false;
         OrderPlaced = false;
        }
     }
   else
      if(IsOrderOpen == true)
        {
         if(PositionsTotal() > 0)
           {
            OrderPlaced = true;
           }
         else
           {
            IsOrderOpen = false;
            OrderPlaced = false;
           }
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

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
