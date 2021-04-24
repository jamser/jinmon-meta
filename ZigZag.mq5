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
//--- input parameters
input double   lots=0.1;
double   tp=21;
double   sl=14;

bool IsOrderOpen = false;
bool OrderPlaced = false;

//--- Price Action Recognition.
//---
int digit1=Digits();
int dig;

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
      (p.high - p.close) > (p.close - p.open) * 2 &&
      (p.open - p.low) > (p.close - p.open) * 2)
      return true;
   else
      return false;
  }

//--- Ng Doji
bool IsNgDoji(MqlRates& p)
  {
   if((p.open > p.close) &&
      (p.high - p.open) > (p.open - p.close) * 2 &&
      (p.close - p.low) > (p.open - p.close) * 2)
      return true;
   else
      return false;
  }

//--- Shooting Star.
bool IsShootingStar(MqlRates& p)
  {
   if((p.close > p.open) &&
      (p.high - p.close) > (p.close - p.open) * 2 &&
      (p.close - p.open) > (p.open - p.low))
      return true;
   else
      return false;
  }

//--- Negative Shooting Star.
bool IsNgShootingStar(MqlRates& p)
  {
   if((p.open > p.close) &&
      (p.high - p.open) > (p.open - p.close) * 2 &&
      (p.open - p.close) > (p.close - p.low))
      return true;
   else
      return false;
  }

//--- Hammer.
bool IsHammer(MqlRates& p)
  {
   if((p.close > p.open) &&
      (p.open - p.low) > (p.close - p.open) * 2 &&
      (p.close - p.open) > (p.high - p.close))
      return true;
   else
      return false;
  }

//--- Negative Hammer.
bool IsNgHammer(MqlRates& p)
  {
   if((p.open > p.close) &&
      (p.close - p.low) > (p.open - p.close) * 2 &&
      (p.open - p.close) > (p.high - p.open))
      return true;
   else
      return false;
  }

//--- Reject
bool IsRejected(MqlRates& p)
  {
   if (IsNgShootingStar(p) ||
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
   if((IsShootingStar((pp)) || IsNgShootingStar(pp)) &&
      (p.open >= p.close) &&
      (pp.low > p.close))
      //(pp.high > p.high))
      return true;
   else
      return false;
  }

//--- Bearish Hopping.
bool IsBearishHopping(MqlRates& p, MqlRates& pp)
  {
   if(IsBlackCandle(p) &&
      IsBlackCandle(pp) &&
      pp.close > p.open)
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
   if((pp.close >= pp.open) &&
      (pp.open - pp.low) > (pp.close - pp.open) &&
      (p.close >= p.open) &&
      (p.open > pp.high) &&
      (p.low > pp.low))
      return true;
   else
      return false;
  }

//--- Bullish Hopping.
bool IsBullishHopping(MqlRates& p, MqlRates& pp)
  {
   if(IsWhiteCandle(p) &&
      IsWhiteCandle(pp) &&
      pp.close < p.open)
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PriceAction()
  {
   dig=digit1-1;
//---- Candle1 OHLC
   double O1=NormalizeDouble(iOpen(Symbol(),PERIOD_M1,2),dig);
   double H1=NormalizeDouble(iHigh(Symbol(),PERIOD_M1,2),dig);
   double L1=NormalizeDouble(iLow(Symbol(),PERIOD_M1,2),dig);
   double C1=NormalizeDouble(iClose(Symbol(),PERIOD_M1,2),dig);
//---- Candle2 OHLC
   double O2=NormalizeDouble(iOpen(Symbol(),PERIOD_M1,1),dig);
   double H2=NormalizeDouble(iHigh(Symbol(),PERIOD_M1,1),dig);
   double L2=NormalizeDouble(iLow(Symbol(),PERIOD_M1,1),dig);
   double C2=NormalizeDouble(iClose(Symbol(),PERIOD_M1,1),dig);
//---- Candle3 OHLC
   double O3=NormalizeDouble(iOpen(Symbol(),PERIOD_M1,0),dig);
   double H3=NormalizeDouble(iHigh(Symbol(),PERIOD_M1,0),dig);
   double L3=NormalizeDouble(iLow(Symbol(),PERIOD_M1,0),dig);
   double C3=NormalizeDouble(iClose(Symbol(),PERIOD_M1,0),dig);

   int type = 0;

//--- Pattern 1 - bullish
   if(C1>=O1 && L1<O1 && ((O1-L1)>(C1-O1)) && C2>=O2 && C2>H1 && L2>L1)
     {
      return 1;
     }
//--- Pattern 2 - bullish
   else
      if(C1<O1 && C2>O2 && ((O1-C1)>(H1-O1)) && ((O1-C1)>(C1-L1)) && ((C2-O2)>(H2-C2)) && ((C2-O2)>(O2-L2)) && O2<=C1 && O2>=L1 && C2>=O1 && C2<=H1)
        {
         return 1;
        }
      //--- Pattern 3 - bullish
      else
         if(C1>O1 && ((C2-O2)>=(H2-C2)) && C2>O2 && C2>C1)
           {
            return 1;
           }

//---- Pattern 1 - bearish
   if(C1 <= O1 && ((H1 - O1) > (O1 - C1)) && (C2 <= O2) && (C2 < L1) && (H2 < H1))
     {
      //Print("Shooting start + Big black candle");
      return -1;
     }
//---- Pattern 2 - bearish
   /*
   if(C1>O1 && C2<O2 && ((C1-O1)>(H1-C1)) && ((C1-O1)>(O1-L1)) && ((O2-C2)>(H2-O2)) && ((O2-C2)>(C2-L2)) && O2>=C1 && O2<=H1 && C2<=O1 && C2>=L1)
     {
      closeOrder = true;
      refHit = false;
     }
     */
//---- Pattern 3 - bearish
   else
      if(C1 < O1 && ((O2 - C2) >= (C2 - L2)) && C2 < O2 && C2 < C1)
        {
         return -1;
        }

      //---- Bullish Engulfing candle.
      else
         if(O2 > C2 && C1 > O1 && O2 > C1 && O1 > C2)
           {
            return -1;
           }

   return 0;
  }

const ENUM_TIMEFRAMES HighLevelTimeFrame = PERIOD_H1;
int PriceActionHL()
  {
   dig=digit1-1;
//---- Candle1 OHLC
   double O1=NormalizeDouble(iOpen(Symbol(),HighLevelTimeFrame,2),dig);
   double H1=NormalizeDouble(iHigh(Symbol(),HighLevelTimeFrame,2),dig);
   double L1=NormalizeDouble(iLow(Symbol(),HighLevelTimeFrame,2),dig);
   double C1=NormalizeDouble(iClose(Symbol(),HighLevelTimeFrame,2),dig);
//---- Candle2 OHLC
   double O2=NormalizeDouble(iOpen(Symbol(),HighLevelTimeFrame,1),dig);
   double H2=NormalizeDouble(iHigh(Symbol(),HighLevelTimeFrame,1),dig);
   double L2=NormalizeDouble(iLow(Symbol(),HighLevelTimeFrame,1),dig);
   double C2=NormalizeDouble(iClose(Symbol(),HighLevelTimeFrame,1),dig);
//---- Candle3 OHLC
   double O3=NormalizeDouble(iOpen(Symbol(),HighLevelTimeFrame,0),dig);
   double H3=NormalizeDouble(iHigh(Symbol(),HighLevelTimeFrame,0),dig);
   double L3=NormalizeDouble(iLow(Symbol(),HighLevelTimeFrame,0),dig);
   double C3=NormalizeDouble(iClose(Symbol(),HighLevelTimeFrame,0),dig);

   int type = 0;

//--- Pattern 1 - bullish
   if(C1>=O1 && L1<O1 && ((O1-L1)>(C1-O1)) && C2>=O2 && C2>H1 && L2>L1)
     {
      return 1;
     }
//--- Pattern 2 - bullish
   else
      if(C1<O1 && C2>O2 && ((O1-C1)>(H1-O1)) && ((O1-C1)>(C1-L1)) && ((C2-O2)>(H2-C2)) && ((C2-O2)>(O2-L2)) && O2<=C1 && O2>=L1 && C2>=O1 && C2<=H1)
        {
         return 1;
        }
      //--- Pattern 3 - bullish
      else
         if(C1>O1 && ((C2-O2)>=(H2-C2)) && C2>O2 && C2>C1)
           {
            return 1;
           }

//---- Pattern 1 - bearish
   if(C1 <= O1 && ((H1 - O1) > (O1 - C1)) && (C2 <= O2) && (C2 < L1) && (H2 < H1))
     {
      //Print("Shooting start + Big black candle");
      return -1;
     }
//---- Pattern 2 - bearish
   if(C1>O1 && C2<O2 && ((C1-O1)>(H1-C1)) && ((C1-O1)>(O1-L1)) && ((O2-C2)>(H2-O2)) && ((O2-C2)>(C2-L2)) && O2>=C1 && O2<=H1 && C2<=O1 && C2>=L1)
     {
      return -1;
     }
//---- Pattern 3 - bearish
   else
      if(C1 < O1 && ((O2 - C2) >= (C2 - L2)) && C2 < O2 && C2 < C1)
        {
         return -1;
        }

      //---- Bullish Engulfing candle.
      else
         if(O2 > C2 && C1 > O1 && O2 > C1 && O1 > C2)
           {
            return -1;
           }
         else
            if(O2 > C2 && C2 > O3 && C2 > C3)
               return -1;

   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

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
double MaxR = 0.1;
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
   int Bars = Bars(_Symbol, PERIOD_M1);
   int    limit = MathMin(Bars,MaxLimit);
   double d1 = prLow(iLowest(NULL,TimeFrame,MODE_LOW,limit,0));
   double d2 = prHigh(iHighest(NULL,TimeFrame,MODE_HIGH,limit,0));

   if(d1Num!=d1||d2Num!=d2)
     {
      ArrayResize(CrossBarsNum, (d2-d1)*100 + 1);
      ArrayResize(CrossBarsMin, (d2-d1)*100 + 1);
      if(d1Num != 0.0 && d1Num != d1)
        {
         ArrayCopy(CrossBarsNum,CrossBarsNum, 0, (d1Num-d1)*100 + 1);
         ArrayCopy(CrossBarsMin,CrossBarsMin, 0, (d1Num-d1)*100 + 1);
        }
      d1Num=d1;
      d2Num=d2;
     }

   int di;
   for(double d=d1; d<=d2; d+=0.01)
     {
      di = (d-d1)*100;
      CrossBarsNum[di] = 0;
      CrossBarsMin[di] = false;
     }

   for(double d=d1; d<=d2; d+=0.01)
     {
      int di = (d-d1)*100;
      for(int i=1; i<limit; i++)
         if(d>prLow(i)&&d<prHigh(i))
            CrossBarsNum[di]++;
     }

   double l=MaxR*100;
   int index = -1;
   for(double d = d1 + MaxR; d <= d2 - MaxR; d += 0.01)
     {
      int di = (d-d1)*100;
      /*
            if(!CrossBarsMin[di] && CrossBarsNum[ArrayMaximum(CrossBarsNum, 2*l, di - l)] -
               CrossBarsNum[ArrayMinimum(CrossBarsNum, 2*l, di - l)] > MaxCrossesLevel &&
               CrossBarsNum[di] == CrossBarsNum[ArrayMinimum(CrossBarsNum, 2*l, di - l)] &&
               CrossBarsNum[di-1] != CrossBarsNum[ArrayMinimum(CrossBarsNum, 2*l, di - l)])
               */
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
   int    start = 0, extreme_search = Extremum;
   int    shift = 0, last_high_pos = 0,last_low_pos = 0;
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
                 }
               if(LowMapBuffer[shift] != 0.0)
                 {
                  last_low = prices[shift].close;
                  last_low_pos = shift;
                  extreme_search = Peak;
                  ZigZagBuffer[shift] = last_low;
                  res = 1;
                 }
              }
            break;
         case Peak:
            if(HighMapBuffer[shift] != 0.0 && LowMapBuffer[shift] == 0.0)
              {
               val = HighMapBuffer[shift];

               if(val - last_low > InpDeviation * _Point)
                 {
                  last_high = val;
                  last_high_pos = shift;
                  ZigZagBuffer[shift] = last_high;
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

               if(last_high - val > InpDeviation * _Point)
                 {
                  last_low = val;
                  last_low_pos = shift;
                  ZigZagBuffer[shift] = last_low;
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

   if (IsInsideBar(prices[0], prices[1])) return false;
   
   switch(type)
     {
      case 1:
         if(CheckHighLeveTrend() == TREND_LOW)
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

         if(IsBullishHopping(p3, p4) && !IsBearishHopping(p1, p2))
           {
            message = "Hopping";
            return true;
           }
         if(IsBullishEngulfing(p3, p4) && !IsBearishHopping(p1, p2) && !IsBearishDoji(p1, p2))
           {
            message = "Engulfing";
            return true;
           }
         if(IsBullishDoji(p3, p4))
           {
            message = "Doji";
            return true;
           }
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

   if (IsInsideBar(prices[0], prices[1])) return false;
   
   switch(type)
     {
      case 1:
         if(CheckHighLeveTrend() == TREND_HIGH)
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
         //if(CheckHighLeveTrend() == TREND_HIGH)
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
            
         if(IsBearishHopping(p3, p4) && !IsBullishHopping(p1, p2))
           {
            message = "Hopping";
            return true;
           }
         if(IsBearishEngulfing(p3, p4) && !IsBullishHopping(p1, p2))
           {
            message = "Engulfing";
            return true;
           }
         if(IsBearishDoji(p3, p4))
           {
            message = "Doji";
            return true;
           }
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
   MqlRates prices[], p1, p2, p3, p4;
   ArraySetAsSeries(prices, true);

//--- 最新的K線還沒完成，略過，不參考．
   CopyRates(_Symbol, zzTimeFrame, 1, 4, prices);

   p1 = prices[0];
   p2 = prices[1];
   p3 = prices[2];
   p4 = prices[3];

   switch(type)
     {
      case 1:
         if (IsShootingStar(p1) || IsShootingStar(p2) || IsNgShootingStar(p1) || IsNgShootingStar(p2))
           {
            message = "Pin Bar";
            return false;
           }

         //--- Pattern: Rejected.
         if(IsBullishHopping(p3, p4) &&
            (  (IsRejected(p2) && IsBlackCandle(p1)) || (IsBlackCandle(p2) && IsRejected(p1))  )
            )
           {
            message = "Hopping then Rejected";
            return true;
           }
         if(IsBullishEngulfing(p3, p4) &&
            (  (IsRejected(p2) && IsBlackCandle(p1)) || (IsBlackCandle(p2) && IsRejected(p1))  )
            )
           {
            message = "Bullish Engulfing then Rejected";
            return true;
           }

           //--- End of Rejected.
           
            
         if(IsBearishEngulfing(p3, p4))
           {
             message = "Engulfing";
            return true;
           }
           
         if(IsBearishDoji(p3, p4))
           {
            message = "Doji";
            return true;
           }
            
         // Hopping
         if(IsBearishHopping(p1, p2) && IsBullishEngulfing(p3, p4))
           {
            message = "Engulfing + Bearish Hopping";
            return true;
           }
         if(IsBearishHopping(p1, p2) && IsBullishHopping(p3, p4))
           {
            message = "Hopping + Bearish Hopping";
            return true;
           }
            
         break;
      case -1:
         if(IsHammer(p1) || IsHammer(p2) || IsNgHammer(p1) || IsNgHammer(p2))
           {
            message = "Pin Bar";
            return false;
           }

         //--- Pattern: Rejected.
         if(IsBearishHopping(p3, p4) &&
            (  (IsRejected(p2) && IsWhiteCandle(p1)) || (IsWhiteCandle(p2) && IsRejected(p1))  )
            )
           {
            message = "Hopping then Rejected";
            return true;
           }
           
         if(IsBearishEngulfing(p3, p4) &&
            (  (IsRejected(p2) && IsWhiteCandle(p1)) || (IsWhiteCandle(p2) && IsRejected(p1))  )
            )
           {
            message = "Bearish Engulfing then Rejected";
            return true;
           }
           //--- End of Rejected.
         
         if(IsBullishEngulfing(p3, p4))
           {
            message = "Engulfing";
            return true;
           }
         if(IsBullishDoji(p3, p4))
           {
            message = "Doji";
            return true;
           }
            
         // Hopping
         if(IsBullishHopping(p1, p2) && IsBearishEngulfing(p3, p4))
           {
            message = "Engulfing + Bullish Hopping";
            return true;
           }
         if(IsBullishHopping(p1, p2) && IsBearishHopping(p3, p4))
           {
            message = "Hopping + Bullish Hopping";
            return true;
           }
            
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
   if(zzIndexM1 >= 6 &&
      zzPricesM1[6] > zzPricesM1[5] &&
      zzPricesM1[4] > zzPricesM1[3] &&
      zzPricesM1[2] > zzPricesM1[1] &&

      zzPricesM1[0] > zzPricesM1[2] &&
      zzPricesM1[2] >= zzPricesM1[4] &&
      zzPricesM1[4] >= zzPricesM1[6] &&

      zzPricesM1[1] > zzPricesM1[3] &&
      zzPricesM1[3] > zzPricesM1[5] &&

      MathAbs(zzPricesM1[0] - zzPricesM1[5]) >= 0.7)
     {
      if(ReversalPADetector(1, message))
         IsOrderOpen = PlaceOrder(SELL_ORDER,lots,Bid,5,zzPricesM1[0] + (sl*10*_Point), "Bullish -> Bearish - " + message);
      else
         if(SwingHighPADetector(2, message))
            IsOrderOpen = PlaceOrder(BUY_ORDER,lots,Ask,5,zzPricesM1[1] - (sl*10*_Point), "Bullish In - " + message);

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

      MathAbs(zzPricesM1[4] - zzPricesM1[1]) >= 0.7 &&
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
   if(zzIndexM1 >= 6 &&
      zzPricesM1[6] < zzPricesM1[5] &&
      zzPricesM1[4] < zzPricesM1[3] &&
      zzPricesM1[2] < zzPricesM1[1] &&

      zzPricesM1[0] < zzPricesM1[2] &&
      zzPricesM1[2] <= zzPricesM1[4] &&
      zzPricesM1[4] <= zzPricesM1[6] &&

      zzPricesM1[1] < zzPricesM1[3] &&
      zzPricesM1[3] < zzPricesM1[5] &&

      MathAbs(zzPricesM1[0] - zzPricesM1[5]) >= 0.7)
     {
      if(ReversalPADetector(-1, message))
         IsOrderOpen = PlaceOrder(BUY_ORDER,lots,Ask,5,zzPricesM1[0] - (sl*10*_Point), "Bearish -> Bullish - " + message);
      else
         if(SwingLowPADetector(2, message))
            IsOrderOpen = PlaceOrder(SELL_ORDER,lots,Bid,5,zzPricesM1[1] + (sl*10*_Point), "Bearish In - " + message);

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
      MathAbs(zzPricesM1[4] - zzPricesM1[1]) >= 0.7 &&
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
HIGH_LEVEL_TREND CheckHighLeveTrend()
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
   if(zzIndexMh >= 6 &&
      zzPricesMh[6] > zzPricesMh[5] &&
      zzPricesMh[4] > zzPricesMh[3] &&
      zzPricesMh[2] > zzPricesMh[1] &&

      zzPricesMh[0] > zzPricesMh[2] &&
      zzPricesMh[2] >= zzPricesMh[4] &&
      zzPricesMh[4] >= zzPricesMh[6] &&
      
      zzPricesMh[1] > zzPricesMh[3] &&
      zzPricesMh[3] > zzPricesMh[5])
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
   if(zzIndexMh >= 6 &&
      zzPricesMh[6] < zzPricesMh[5] &&
      zzPricesMh[4] < zzPricesMh[3] &&
      zzPricesMh[2] < zzPricesMh[1] &&

      zzPricesMh[0] < zzPricesMh[2] &&
      zzPricesMh[2] <= zzPricesMh[4] &&
      zzPricesMh[4] <= zzPricesMh[6] &&
      
      zzPricesMh[1] < zzPricesMh[3] &&
      zzPricesMh[3] < zzPricesMh[5])
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

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   if(OrderPlaced && (Time(0) - OrderTime) > MinHoldTime)
     {
      dig=digit1-1;
      //---- Candle1 OHLC
      MqlRates prices[], p, pp, ppp;
      ArraySetAsSeries(prices, true);
      CopyRates(_Symbol, PERIOD_M1, 0, 3, prices);

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
      if(OrderType == BUY_ORDER && p.close > OrderPrice + (tp*10*_Point))
        {

         //---- Pattern 1 - bearish doji
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
      if(OrderType == SELL_ORDER && p.close < OrderPrice - (tp*10*_Point))
        {

         //---- Pattern 1 - bearish
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
      HIGH_LEVEL_TREND  trend = CheckHighLeveTrend();
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
