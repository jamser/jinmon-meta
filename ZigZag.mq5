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

const int SELL_ORDER = -1;
const int BUY_ORDER = 1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionInfo position;
CTrade trade;

int MinHoldTime = 10*60;   // seconds
double OrderPrice = 0.0;
datetime OrderTime;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong PlaceOrder(int cmd, double volume, double price, int slippage, double stoploss, double takeprofit)
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
   request.type = (cmd == SELL_ORDER ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   request.volume = volume;
   request.deviation = slippage;
   request.sl = stoploss;
//request.tp = takeprofit;
   request.price = price;

   MqlTradeResult result = {0};
   if(trade.OrderSend(request, result))
     {
      OrderPrice = price;
      OrderTime = Time(0);
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

//--- input parameters
input double   lots=0.1;
input double   tp=21;
input double   sl=14;

//--- Price Action Recognition.
bool IsOrderOpen = false;
bool OrderPlaced = false;
//---
int digit1=Digits();
int dig;
//---
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
ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;
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

int zzIndex = 0;
double zzPrices[7];
datetime zzTime[7];

enum EnSearchMode
  {
   Extremum=0, // searching for the first extremum
   Peak=1,     // searching for the next ZigZag peak
   Bottom=-1   // searching for the next ZigZag bottom
  };

ENUM_TIMEFRAMES zzTimeFrame = PERIOD_M1;

//+------------------------------------------------------------------+
double Low(int shift)
  {
   return iLow(_Symbol, zzTimeFrame, shift);
  }

//+------------------------------------------------------------------+
double High(int shift)
  {
   return iHigh(_Symbol, zzTimeFrame, shift);
  }
//+------------------------------------------------------------------+
double Close(int shift)
  {
   return iClose(_Symbol, zzTimeFrame, shift);
  }
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
const int SwingTimeSpan = 240;
int CalculateHighLow()
  {
   if(Bars(_Symbol, zzTimeFrame) < SwingTimeSpan)
      return(0);

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

   int dir = (Close(SwingTimeSpan - 2) > Close(SwingTimeSpan - 1) ? 1 : -1);

//--- searching for high and low extremes
   double pv = Close(SwingTimeSpan - 1);
   for(shift = SwingTimeSpan - 2; shift >= 0; shift --)
     {
      val = Close(shift);
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
   for(shift = SwingTimeSpan - 1; shift >= 0; shift --)
      //for (shift = 0; shift < SwingTimeSpan; shift ++)
     {
      res = 0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low == 0.0 && last_high == 0.0)
              {
               /*
                if(HighMapBuffer[shift] != 0)
                  {
                   last_high = High(shift);
                   last_high_pos = shift;
                   extreme_search = Bottom;
                   ZigZagBuffer[shift] = last_high;
                   res = 1;
                  }
                  */
               if(LowMapBuffer[shift] != 0.0)
                 {
                  last_low = Low(shift);
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

               // noise filtering.
               //               if (val - last_low < InpDeviation * _Point) {
               //                  ZigZagBuffer[last_low_pos] = 0.0;
               //               }
               //               else {
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

               // noise filtering.
               //               if (last_high - val < InpDeviation * _Point) {
               //                  ZigZagBuffer[last_high_pos] = 0.0;
               //               }
               //               else {
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

   zzIndex = 0;
//Print("---- zz ----");
   for(shift = 0; shift < SwingTimeSpan; shift ++)
     {
      // find out prices and times.
      if(ZigZagBuffer[shift] > 0 && zzIndex < 7)
        {
         zzPrices[zzIndex] = ZigZagBuffer[shift];
         zzTime[zzIndex] = Time(shift);
         zzIndex ++;
         //Print(zzIndex + " P = ", ZigZagBuffer[shift], " : ", shift);
        }
     }
   return 0;
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
   for(i = 0; i < zzIndex - 1; i ++)
     {
      const string id = "zigzag-" + i;
      ObjectMove(0, id, 0, zzTime[i], zzPrices[i]);
      ObjectMove(0, id, 1, zzTime[i + 1], zzPrices[i + 1]);
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, false);
     }

   for(; i < 6; i ++)
     {
      const string id = "zigzag-" + i;
      ObjectSetInteger(0, id, OBJPROP_HIDDEN, true);
     }
  }
//+------------------------------------------------------------------+
//| Swing High Trading                                               |
//+------------------------------------------------------------------+
bool CheckSwingHigh()
  {
   //int highPos = iHighest(_Symbol, PERIOD_M5, MODE_CLOSE, 24, 0);
   //int lowPos = iLowest(_Symbol, PERIOD_M5, MODE_CLOSE, 24, 0);

   //if(highPos > lowPos || highPos > 8)
   //   return false;
//Print("trend high ...");

   if(zzIndex < 7)
      return false;
   if(zzPrices[6] > zzPrices[5])
      return false;
   if(zzPrices[5] > zzPrices[3])
      return false;
   if(zzPrices[3] > zzPrices[1])
      return false;

//if (zzPrices[6] > zzPrices[4]) return ;

   if(zzPrices[5] < zzPrices[4])
      return false;
   if(zzPrices[3] < zzPrices[2])
      return false;

   if(zzPrices[0] <= zzPrices[3])
      return false;

   if(zzPrices[0] >= zzPrices[1])
      return false;

// Place order when bullish.
   if(PriceActionHL() == BEARISH)
     {
      Print("Avoid Bearish !!!");
      return false;
     }

// Passed, place order.
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   IsOrderOpen = PlaceOrder(BUY_ORDER,lots,Ask,5,zzPrices[2] - (sl*10*_Point),Ask + (tp*10*_Point));
   return IsOrderOpen;
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

      bool closeOrder = false;

      if(!refHit)
        {
         double ref;
         for(int i = 0; i <= refIndex; i ++)
           {
            ref = Refs[i];
            if((H3==ref) || (L3==ref) || ((H3>ref) && (L3<ref)) || ((L2<ref) && (H3>=ref)) || ((H2>ref) && (L3<=ref)))
              {
               refHit = true;
               targetRef = ref;
               PrintFormat("Hit Price %.2f", targetRef);
              }
           }
        }
        {
         // Close price must greater than order price.

         if(refHit)
           {
            // Hit Support.
            if(OrderPrice > targetRef)
              {
               refHit = false;
               return ;
              }
            // Hit Resistance.
            else
               closeOrder = true;
           }

         if(C3 > OrderPrice + (sl*10*_Point))
           {

            //---- Pattern 1 - bearish
            if(C1 <= O1 && ((H1 - O1) > (O1 - C1)) && (C2 <= O2) && (C2 < L1) && (H2 < H1))
              {
               Print("Shooting start + Big black candle");
               closeOrder = true;
               refHit = false;
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

            if(C1 < O1 && ((O2 - C2) >= (C2 - L2)) && C2 < O2 && C2 < C1)
              {
               closeOrder = true;
               refHit = false;
              }

            //---- Bullish Engulfing candle.
            if(O2 > C2 && C1 > O1 && O2 > C1 && O1 > C2)
              {
               closeOrder = true;
               refHit = false;
               Print("Bearish Engulfing candle");
              }
            //---- Stand above Resistance.
            if(L1 >= targetRef && L2 >= targetRef && L3 >= targetRef)
              {
               refHit = false;
               //PrintFormat("Overcoming Resistance %.2f", targetRef);
              }
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
        }

     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+

const int BULLISH = 1;
const int BEARISH = -1;

//---
void OnTimer()
  {
   int n = FindLevel();
   UpdateKeyLevels(n);

   CalculateHighLow();
   UpdateZigZagLines();

// is time to place order ?
   if(!IsOrderOpen)
     {
      CheckSwingHigh();
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
