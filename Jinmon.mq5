//+------------------------------------------------------------------+
//|                                                       Jinmon.mq5 |
//|                                                              Lex |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex"
#property link      ""
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

input long order_magic = 55555;

const int SELL_ORDER = -1;
const int BUY_ORDER = 1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionInfo position;
CTrade trade;

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
//   request.tp = takeprofit;
   request.price = price;

   MqlTradeResult result = {0};
   if(trade.OrderSend(request, result))
     {
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
input bool   UsePattern1bullish=true;
input bool   UsePattern2bullish=true;
input bool   UsePattern3bullish=true;
bool   UsePattern1bearish=false;
bool   UsePattern2bearish=false;
bool   UsePattern3bearish=false;

//---
int refIndex = -1;
bool refHit = false;
double Refs[100];
double targetRef;

//--- Price Action Recognition.
bool orderopen = false;
bool orderplaced = false;
//---
bool close1;
bool modify1;
//---
int digit1=Digits();
int dig;
//---
void PriceAction()
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

//---- Check to see if Reference Price (ref) is reached
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
           }
        }
      return ;
     }
//---- Check for patterns if no position has been opened
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Point = Point();

   if(orderopen == false)
     {
      //--- Pattern 1 - bullish
      if(UsePattern1bullish && refHit && C1>=O1 && L1<O1 && ((O1-L1)>(C1-O1)) && C2>=O2 && C2>H1 && L2>L1 && C2>targetRef)
        {
         orderopen=PlaceOrder(BUY_ORDER,lots,Ask,5,Bid-(sl*10*Point),Bid+(tp*10*Point));
         return ;
        }
      //--- Pattern 2 - bullish
      if(UsePattern2bullish && refHit && C1<O1 && C2>O2 && ((O1-C1)>(H1-O1)) && ((O1-C1)>(C1-L1)) && ((C2-O2)>(H2-C2)) && ((C2-O2)>(O2-L2)) && O2<=C1 && O2>=L1 && C2>=O1 && C2<=H1 && C2>targetRef)
        {
         orderopen=PlaceOrder(BUY_ORDER,lots,Ask,5,Bid-(sl*10*Point),Bid+(tp*10*Point));
         return ;
        }
      //--- Pattern 3 - bullish
      if(UsePattern3bullish && refHit && C1>O1 && ((C2-O2)>=(H2-C2)) && C2>O2 && C2>C1 && C1>targetRef && C2>targetRef)
        {
         orderopen=PlaceOrder(BUY_ORDER,lots,Ask,5,Bid-(sl*10*Point),Bid+(tp*10*Point));
         return ;
        }
      //---- Pattern 1 - bearish
      if(UsePattern1bearish && refHit && C1<=O1 && H1>O1 && ((H1-O1)>(O1-C1)) && C2<=O2 && C2<L1 && H2<H1 && C2<targetRef)
        {
         orderopen=PlaceOrder(SELL_ORDER,lots,Bid,5,Ask+(sl*10*Point),Ask-(tp*10*Point));
         return ;
        }
      //---- Pattern 2 - bearish
      if(UsePattern2bearish && refHit && C1>O1 && C2<O2 && ((C1-O1)>(H1-C1)) && ((C1-O1)>(O1-L1)) && ((O2-C2)>(H2-O2)) && ((O2-C2)>(C2-L2)) && O2>=C1 && O2<=H1 && C2<=O1 && C2>=L1 && C2<targetRef)
        {
         orderopen=PlaceOrder(SELL_ORDER,lots,Bid,5,Ask+(sl*10*Point),Ask-(tp*10*Point));
         return ;
        }
      //---- Pattern 3 - bearish
      if(UsePattern3bearish && refHit && C1<O1 && ((O2-C2)>=(C2-L2)) && C2<O2 && C2<C1 && C1<targetRef && C2<targetRef)
        {
         orderopen=PlaceOrder(SELL_ORDER,lots,Bid,5,Ask+(sl*10*Point),Ask-(tp*10*Point));
         return ;
        }
     }
   else
      if(orderplaced)
        {
         bool closeOrder = false;
         //---- Pattern 1 - bearish
         if(C1<=O1 && H1>O1 && ((H1-O1)>(O1-C1)) && C2<=O2 && C2<L1 && H2<H1)
           {
            closeOrder = true;
           }
         //---- Pattern 2 - bearish
         else
            if(C1>O1 && C2<O2 && ((C1-O1)>(H1-C1)) && ((C1-O1)>(O1-L1)) && ((O2-C2)>(H2-O2)) && ((O2-C2)>(C2-L2)) && O2>=C1 && O2<=H1 && C2<=O1 && C2>=L1)
              {
               closeOrder = true;
              }
            //---- Pattern 3 - bearish
            else
               if(C1<O1 && ((O2-C2)>=(C2-L2)) && C2<O2 && C2<C1)
                 {
                  closeOrder = true;
                 }
         //--- Close position while bearish.
         if(closeOrder)
           {
            if(CloseOrder(lots))
            {
               Print("Close Position to protect profits!");
               orderopen = false;
               orderplaced = false;
               refHit = false;
            }
            else
               Print("Failed to close position!!!");
           }
        }

  }
//+------------------------------------------------------------------+
//| Support and Resistance                                           |
//+------------------------------------------------------------------+
//---
input int MaxLimit = 55;
input int MaxCrossesLevel = 9;
double MaxR = 0.1;
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M30;
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
void FindLevel()
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

   CopyTime(_Symbol, TimeFrame, 0, limit, Time);

   for(double d=d1; d<=d2; d+=0.01)
     {
      int di = (d-d1)*100;
      for(int i=1; i<limit; i++)
         if(d>prLow(i)&&d<prHigh(i))
            CrossBarsNum[di]++;
      //if(TMaxI != 0 && Time[limit - 1] != TMaxI)
      //if(d > prLow(limit + 1) && d < prHigh(limit + 1))
      //   CrossBarsNum[di]--;
      if(TMaxI != 0 && Time[limit - 1] != TMaxI)
         if(d > prLow(iBarShift(NULL,0,TMaxI)) && d < prHigh(iBarShift(NULL,0,TMaxI)))
            CrossBarsNum[di]--;

     }
   TMaxI = Time[limit - 1] - 1;

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
         PrintFormat("key level = %.2f", d);
         index ++;
         Refs[index] = d;
        }

      if(CrossBarsMin[di]&&CrossBarsNum[di]!=CrossBarsNum[ArrayMinimum(CrossBarsNum,2*l,di-l)])
        {
         CrossBarsMin[di]=false;
         //ignore ObjectDelete(Period2AlpthabetString(TimeFrame)+TimeFrame+"_"+d);
        }

     }
   if(index > -1)
     {
      refIndex = index;
      PrintFormat("refs no. = %d", refIndex);
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);

//---
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
   PriceAction();
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   FindLevel();

   if(orderplaced == true)
     {
      if(PositionsTotal() == 0)
        {
         Print("Order Closed");
         orderopen = false;
         orderplaced = false;
         refHit = false;
        }
     }
   else
      if(orderopen == true)
        {
         if(PositionsTotal() > 0) {
            orderplaced = true;
            //refHit = false;
         }
         else
           {
            orderopen = false;
            orderplaced = false;
            refHit = false;
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
