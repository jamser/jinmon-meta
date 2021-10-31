//+------------------------------------------------------------------+
//|                                                  JinmonAgent.mq5 |
//|                                         Lex Yang @ Jinmon Island |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex Yang @ Jinmon Island"
#property link      ""
#property version   "0.01"

#include <JAson.mqh>

#include <Trade\SymbolInfo.mqh>
#include <Indicators\Indicators.mqh>

#include <Expert\Trailing\TrailingMA.mqh>
#include <Expert\Trailing\TrailingParabolicSAR.mqh>

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

//--- input parameters
input long     order_magic = 55555;

input double   additionLot=0;
input double   slDelta=3;
input double   tpDelta=0;
input double   orderLot=0.5;

//--- Trade variables.
double TickSize;

const string   SELL_ORDER = "sell";
const string   BUY_ORDER = "buy";
const string   CLOSE_ORDER = "close";

CSymbolInfo xauSymbol;
CIndicators indicators;
CTrailingPSAR trailing;

CPositionInfo position;
CTrade trade;

enum ENUM_SIGNAL_STATE
  {
   FIND_POINT_1 = 0,
   FIND_POINT_2 = 1,
   PREPARE_TO_TRADE = 2,
  };

enum ENUM_TREND_STATE
  {
   NONE_TREND = 0,
   BEARISH_TREND = 1,
   BULLISH_TREND = 2,
  };

ENUM_SIGNAL_STATE eaState = FIND_POINT_1;
ENUM_SIGNAL_STATE eaTrend = FIND_POINT_1;

ENUM_TREND_STATE trend = NONE_TREND;

//--- input parameters
input bool     InpVerbose=false;          // Verbose
input bool     InpDryRun=false;           // Dry Run
input int      InpBackTrackBars = 0;
input double   InpPoint2Margin = 0.08;

input ENUM_TIMEFRAMES   p1TimeFrame = PERIOD_M1;
input ENUM_TIMEFRAMES   p2TimeFrame = PERIOD_M15;

//--- misc. variables
int      backTrackBars = 0;

//--- A/D% Indicator
int p1ADpHandle;
int p2ADpHandle;

double p1adp[];
double p2adp[];

//--- Bollinger Band% Indicator
int p1BollPercentHandle;
int p2BollPercentHandle;

double p1bbp[];
double p1sr[];
double p1ml[];

double p2bbp[];
double p2sr[];
double p2ml[];

//--- Variables for Trend Signal
datetime    ppt1Time = 0;
double      ppt1Price = 0;
double      ppt1PercentB = 0;
double      ppt1ADP = 0;

datetime    ppt2Time = 0;
double      ppt2Price = 0;
double      ppt2PercentB = 0;
double      ppt2ADP = 0;

//--- Variables for Trading Signal
datetime    pt1Time = 0;
double      pt1Price = 0;
double      pt1PercentB = 0;
double      pt1ADP = 0;

datetime    pt2Time = 0;
double      pt2Price = 0;
double      pt2PercentB = 0;
double      pt2ADP = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- P1 Bollinger Band% Indicator
   p1BollPercentHandle = iCustom(_Symbol, p1TimeFrame, "PercentBB");
   if(p1BollPercentHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the BB% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p1bbp, true);
   ArraySetAsSeries(p1sr, true);
   ArraySetAsSeries(p1ml, true);

//--- P1 Accumlation / Distribution % Indicator
   p1ADpHandle = iCustom(_Symbol, p1TimeFrame, "PercentAD");
   if(p1ADpHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the A/D% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p1adp, true);

//--- P2 Bollinger Band% Indicator
   p2BollPercentHandle = iCustom(_Symbol, p1TimeFrame, "PercentBB");
   if(p2BollPercentHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the BB% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p2bbp, true);
   ArraySetAsSeries(p2sr, true);
   ArraySetAsSeries(p2ml, true);

//--- P2 Accumlation / Distribution % Indicator
   p2ADpHandle = iCustom(_Symbol, p2TimeFrame, "PercentAD");
   if(p2ADpHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the A/D% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p2adp, true);

//--- Initialize Buffers
   UpdateP1Buffer();

//--- Init Symbol.
   xauSymbol.Name(_Symbol);
   TickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

//--- Setup Trailing Stop
   trailing.Init(&xauSymbol, p1TimeFrame, _Point);
   trailing.InitIndicators(&indicators);

//--- Initialize Trade Object.
   trade.SetExpertMagicNumber(order_magic);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(false);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(p1ADpHandle);
   IndicatorRelease(p1BollPercentHandle);
  }

//+------------------------------------------------------------------+
//| Sell Trader                                                      |
//+------------------------------------------------------------------+
void UpdateSellPoint1()
  {
   pt1Price = iClose(NULL, p1TimeFrame, 1);
   pt1Time = iTime(NULL, p1TimeFrame, 1);
   pt1PercentB = p1bbp[1];
   pt1ADP = p1adp[1];
  }

//+------------------------------------------------------------------+
//| Sell Trader                                                      |
//+------------------------------------------------------------------+
void UpdateSellPoint2()
  {
   pt2Price = iClose(NULL, p1TimeFrame, 2);
   pt2Time = iTime(NULL, p1TimeFrame, 2);
   pt2PercentB = p1bbp[2];
   pt2ADP = p1adp[2];
  }

//+------------------------------------------------------------------+
//| Sell Trader                                                      |
//+------------------------------------------------------------------+
bool ConfirmIndicatorSell()
  {
   return (pt1ADP > pt2ADP);
  }

//+------------------------------------------------------------------+
//| Sell Trader                                                      |
//+------------------------------------------------------------------+
bool ShortStrategy()
  {
   switch(eaState)
     {
      case FIND_POINT_1:
         if(p1bbp[1] >= 0.5)
           {
            UpdateSellPoint1();

            eaState = FIND_POINT_2;
           }
         break;
      case FIND_POINT_2:
         if(pt1Time == iTime(NULL, p1TimeFrame, 1))
            return false;

         if(p1bbp[1] >= 0.5)
           {
            UpdateSellPoint1();
            break;
           }

         if((0.5 > p1bbp[2]) && (p1bbp[2] > 0.5 - InpPoint2Margin) &&
            (p1bbp[3] < p1bbp[2]) && (p1bbp[2] > p1bbp[1]))
           {
            UpdateSellPoint2();

            if(ConfirmIndicatorSell())
               eaState = PREPARE_TO_TRADE;
            else
               eaState = FIND_POINT_1;
           }
         break;
      case PREPARE_TO_TRADE:
         // Sell when change A/D% color.
         if(p1adp[1] < 0)
           {
            eaState = FIND_POINT_1;
            return true;
           }
         break;
      default:
         break;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Buy Trader                                                      |
//+------------------------------------------------------------------+
void UpdateBuyPoint1()
  {
   pt1Price = iClose(NULL, p1TimeFrame, 1);
   pt1Time = iTime(NULL, p1TimeFrame, 1);
   pt1PercentB = p1bbp[1];
   pt1ADP = p1adp[1];
  }

//+------------------------------------------------------------------+
//| Buy Trader                                                      |
//+------------------------------------------------------------------+
void UpdateBuyPoint2()
  {
   pt2Price = iClose(NULL, p1TimeFrame, 2);
   pt2Time = iTime(NULL, p1TimeFrame, 2);
   pt2PercentB = p1bbp[2];
   pt2ADP = p1adp[2];
  }

//+------------------------------------------------------------------+
//| Buy Trader                                                      |
//+------------------------------------------------------------------+
bool ConfirmIndicatorBuy()
  {
   return (pt1ADP < pt2ADP);
  }

//+------------------------------------------------------------------+
//| Buy Trader                                                      |
//+------------------------------------------------------------------+
bool LongStrategy()
  {
   switch(eaState)
     {
      case FIND_POINT_1:
         if(p1bbp[1] <= -0.5)
           {
            UpdateBuyPoint1();

            eaState = FIND_POINT_2;
           }
         break;
      case FIND_POINT_2:
         if(pt1Time == iTime(NULL, p1TimeFrame, 1))
            return false;

         if(p1bbp[1] <= -0.5)
           {
            UpdateBuyPoint1();
            break;
           }

         if((p1bbp[2] > -0.5) && (-0.5 + InpPoint2Margin > p1bbp[2]) &&
            (p1bbp[3] > p1bbp[2]) && (p1bbp[2] < p1bbp[1]))
           {
            UpdateBuyPoint2();

            if(ConfirmIndicatorBuy())
               eaState = PREPARE_TO_TRADE;
            else
               eaState = FIND_POINT_1;
           }
         break;
      case PREPARE_TO_TRADE:
         // Sell when change A/D% color.
         if(p1adp[1] > 0)
           {
            eaState = FIND_POINT_1;
            return true;
           }
         break;
      default:
         break;
     }

   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   xauSymbol.RefreshRates();
   indicators.Refresh();

   UpdateP1Buffer();
   UpdateP2Buffer();

// Check Trend.
   switch(trend)
     {
      case NONE_TREND:
         CheckReverseToBearish();
         CheckReverseToBullish();
         break;
      case BEARISH_TREND:
         CheckReverseToBullish();
         break;
      case BULLISH_TREND:
         CheckReverseToBearish();
         break;
     }

// Check Trading Signal.
   if(PositionsTotal() == 0)
     {
      switch(trend)
        {
         case BEARISH_TREND:
            if(ShortStrategy())
               PlaceOrder(SELL_ORDER);
            break;
         case BULLISH_TREND:
            if(LongStrategy())
               PlaceOrder(BUY_ORDER);
            break;
        }
     }
   else
     {
      switch(trend)
        {
         case BEARISH_TREND:
            //if(LongStrategy())
            //   CloseOrder();
            break;
         case BULLISH_TREND:
            //if(ShortStrategy())
            //   CloseOrder();
            break;
        }

      double sl, newSL, open, tmp;
      
      position.SelectByIndex(0);
      switch(position.PositionType())
        {
         case POSITION_TYPE_SELL:
            if(trailing.CheckTrailingStopShort(&position, newSL, tmp))
              {
               newSL = NormalizeDouble(MathRound(newSL / TickSize) * TickSize, _Digits);

               // There is change of TakeProfit.
               sl = position.StopLoss();
               if(sl == newSL) return ;

               open = position.PriceOpen();

               if(newSL + slDelta >= open) return ;

               //sl = NormalizeDouble(MathRound(sl / TickSize) * TickSize, _Digits);
               ulong ticket = position.Ticket();

               if(trade.PositionModify(ticket, newSL, 0))
                 {
                  Print("Update (" + ticket + ") StopLoss: " + newSL);
                 }
              }
            break;
         case POSITION_TYPE_BUY:
            if(trailing.CheckTrailingStopLong(&position, newSL, tmp))
              {
               newSL = NormalizeDouble(MathRound(newSL / TickSize) * TickSize, _Digits);

               // There is change of TakeProfit.
               sl = position.StopLoss();
               if(sl == newSL) return ;

               open = position.PriceOpen();
               
               if(newSL - slDelta <= open) return ;
               
               //sl = NormalizeDouble(MathRound(sl / TickSize) * TickSize, _Digits);
               ulong ticket = position.Ticket();

               if(trade.PositionModify(ticket, newSL, 0))
                 {
                  Print("Update (" + ticket + ") StopLoss: " + newSL);
                 }

              }
            break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceOrder(string action)
  {
   double stoploss = 0;
   double take_profit = 0;
   const double lot = orderLot;

   MqlTick latest_price;
   SymbolInfoTick(_Symbol, latest_price);

   if(slDelta)
      stoploss = (action == SELL_ORDER) ? (latest_price.ask + slDelta) : (latest_price.bid - slDelta);

   if(tpDelta)
      take_profit = (action == SELL_ORDER) ? (latest_price.ask - tpDelta) : (latest_price.bid + tpDelta);

   Print("Lot: ", lot);
   Print("StopLoss: ", stoploss);
   Print("Action: ", action);

// Dry-Run only for debugging.
   if(InpDryRun)
      return ;

   if(action == SELL_ORDER)
     {
      if(PositionsTotal() == 0)
        {
         trade.Sell(lot, NULL, 0, stoploss, take_profit, "Bearish Sell at " + latest_price.ask);
         Print("--------------------");
         Print(">> Sell " + lot + " at " + latest_price.bid + ", sl: " + stoploss);
         Print("--------------------");
        }
      else
        {
         position.SelectByIndex(0);
         if(position.PositionType() == POSITION_TYPE_BUY)
           {
            CloseOrder();
            Print("--------------------");
            Print(">> Close order");
            Print("--------------------");
           }

        }
     }

   if(action == BUY_ORDER)
     {
      if(PositionsTotal() == 0)
        {
         trade.Buy(lot, NULL, 0, stoploss, take_profit, "Bullish Buy at " + latest_price.bid);
         Print("--------------------");
         Print(">> Buy " + lot + " at " + latest_price.ask + ", sl: " + stoploss);
         Print("--------------------");
        }
      else
        {
         position.SelectByIndex(0);
         if(position.PositionType() == POSITION_TYPE_SELL)
           {
            CloseOrder();
            Print("--------------------");
            Print(">> Close order");
            Print("--------------------");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CloseOrder()
  {
   for(int count = PositionsTotal(); count > 0; count --)
     {
      if(position.SelectByIndex(count - 1))
         !trade.PositionClose(position.Ticket());
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateP1Buffer()
  {
//--- Retrieve BB% Indicator Data
   CopyBuffer(p1BollPercentHandle, 0, 0, InpBackTrackBars, p1bbp);
   CopyBuffer(p1BollPercentHandle, 1, 0, InpBackTrackBars, p1sr);
   CopyBuffer(p1BollPercentHandle, 2, 0, InpBackTrackBars, p1ml);

//--- Retrieve A/D% Indicator Data
   CopyBuffer(p1ADpHandle, 0, 0, InpBackTrackBars, p1adp);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateP2Buffer()
  {
//--- Retrieve BB% Indicator Data
   CopyBuffer(p2BollPercentHandle, 0, 0, InpBackTrackBars, p2bbp);
   CopyBuffer(p2BollPercentHandle, 1, 0, InpBackTrackBars, p2sr);
   CopyBuffer(p2BollPercentHandle, 2, 0, InpBackTrackBars, p2ml);

//--- Retrieve A/D% Indicator Data
   CopyBuffer(p2ADpHandle, 0, 0, InpBackTrackBars, p2adp);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Bearish Trend                                                    |
//+------------------------------------------------------------------+
void UpdateBearishPoint1()
  {
   ppt1Time = iTime(NULL, p2TimeFrame, 1);
   ppt1Price = iClose(NULL, p2TimeFrame, 1);
   ppt1PercentB = p2bbp[1];
   ppt1ADP = p2adp[1];
  }

//+------------------------------------------------------------------+
//| Bearish Trend                                                    |
//+------------------------------------------------------------------+
void UpdateBearishPoint2()
  {
   ppt2Time = iTime(NULL, p2TimeFrame, 2);
   ppt2Price = iClose(NULL, p2TimeFrame, 2);
   ppt2PercentB = p2bbp[2];
   ppt2ADP = p2adp[2];
  }

//+------------------------------------------------------------------+
//| Bearish Trend                                                    |
//+------------------------------------------------------------------+
bool ConfirmBearishTrend()
  {
   return (ppt1ADP > ppt2ADP);
  }

//+------------------------------------------------------------------+
//| Bearish Trend                                                    |
//+------------------------------------------------------------------+
void CheckReverseToBearish()
  {
   switch(eaTrend)
     {
      case FIND_POINT_1:
         if(p2bbp[1] >= 0.5)
           {
            UpdateBearishPoint1();

            eaTrend = FIND_POINT_2;
           }
         break;
      case FIND_POINT_2:
         if(ppt2Time == iTime(NULL, p2TimeFrame, 1))
            return ;

         if(p2bbp[1] >= 0.5)
           {
            UpdateBearishPoint1();
            break;
           }

         if((0.5 > p2bbp[2]) && (p2bbp[2] > 0.5 - InpPoint2Margin) &&
            (p2bbp[3] < p2bbp[2]) && (p2bbp[2] > p2bbp[1]))
           {
            UpdateBearishPoint2();

            if(ConfirmBearishTrend())
               eaTrend = PREPARE_TO_TRADE;
            else
               eaTrend = FIND_POINT_1;
           }
         break;
      case PREPARE_TO_TRADE:
         // Sell when change A/D% color.
         if(p2adp[1] < 0)
           {
            trend = BEARISH_TREND;
            eaTrend = FIND_POINT_1;
           }
         break;
      default:
         break;
     }
  }

//+------------------------------------------------------------------+
//| Bullish Trend                                                    |
//+------------------------------------------------------------------+
void UpdateBullishPoint1()
  {
   ppt1Price = iClose(NULL, p2TimeFrame, 1);
   ppt1Time = iTime(NULL, p2TimeFrame, 1);
   ppt1PercentB = p2bbp[1];
   ppt1ADP = p2adp[1];
  }

//+------------------------------------------------------------------+
//| Bullish Trend                                                    |
//+------------------------------------------------------------------+
void UpdateBullishPoint2()
  {
   ppt2Price = iClose(NULL, p2TimeFrame, 2);
   ppt2Time = iTime(NULL, p2TimeFrame, 2);
   ppt2PercentB = p2bbp[2];
   ppt2ADP = p2adp[2];
  }

//+------------------------------------------------------------------+
//| Bullish Trend                                                    |
//+------------------------------------------------------------------+
bool ConfirmBullishTrend()
  {
   return (ppt1ADP < ppt2ADP);
  }

//+------------------------------------------------------------------+
//| Bullish Trend                                                    |
//+------------------------------------------------------------------+
void CheckReverseToBullish()
  {
   switch(eaTrend)
     {
      case FIND_POINT_1:
         if(p2bbp[1] <= -0.5)
           {
            UpdateBullishPoint1();

            eaTrend = FIND_POINT_2;
           }
         break;
      case FIND_POINT_2:
         if(ppt1Time == iTime(NULL, p2TimeFrame, 1))
            return ;

         if(p2bbp[1] <= -0.5)
           {
            UpdateBullishPoint1();
            break;
           }

         if((p2bbp[2] > -0.5) && (-0.5 + InpPoint2Margin > p2bbp[2]) &&
            (p2bbp[3] > p2bbp[2]) && (p2bbp[2] < p2bbp[1]))
           {
            UpdateBullishPoint2();

            if(ConfirmBullishTrend())
               eaTrend = PREPARE_TO_TRADE;
            else
               eaTrend = FIND_POINT_1;
           }
         break;
      case PREPARE_TO_TRADE:
         // Sell when change A/D% color.
         if(p2adp[1] > 0)
           {
            trend = BULLISH_TREND;
            eaState = FIND_POINT_1;
           }
         break;
      default:
         break;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
