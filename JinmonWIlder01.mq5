//+------------------------------------------------------------------+
//|                                               JinmonWilder01.mq5 |
//|                                         Lex Yang @ Jinmon Island |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex Yang @ Jinmon Island"
#property link      ""
#property version   "0.01"

#include <Trade\SymbolInfo.mqh>
#include <Indicators\Indicators.mqh>
#include <Indicators\Trend.mqh>

#include <Expert\Trailing\TrailingParabolicSAR.mqh>

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

//--- input parameters
input long     order_magic = 55555;

input double   orderLot=0.1;

input int      ADXPeriod = 12;
input double   StrengthThreshold = 20;
input double   DirectionThreshold = 20;

//--- Trade variables.
const string   SELL_ORDER = "sell";
const string   BUY_ORDER = "buy";
const string   CLOSE_ORDER = "close";

CSymbolInfo xauSymbol;
CIndicators indicators;
CTrailingPSAR trailing;

CiADXWilder ADX;

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

ENUM_TREND_STATE trend = NONE_TREND;

//--- input parameters
input bool     InpVerbose=false;          // Verbose
input bool     InpDryRun=false;           // Dry Run

input ENUM_TIMEFRAMES   LowTF  = PERIOD_M1;
input ENUM_TIMEFRAMES   HighTF = PERIOD_M15;

//--- misc. variables

//--- Bollinger Band% Indicator
int p2BollPercentHandle;

double p2bbp[];
double p2sr[];
double p2ml[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- P2 Bollinger Band% Indicator
   p2BollPercentHandle = iCustom(_Symbol, HighTF, "PercentBB");
   if(p2BollPercentHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the BB% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p2bbp, true);
   ArraySetAsSeries(p2sr, true);
   ArraySetAsSeries(p2ml, true);

//--- Init Symbol.
   xauSymbol.Name(_Symbol);

//--- Setup ADX.
   if(!ADX.Create(_Symbol, HighTF, ADXPeriod))
      return INIT_FAILED;

   indicators.Add(GetPointer(ADX));

//--- Setup Trailing Stop
   trailing.Init(&xauSymbol, HighTF, _Point);
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
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double prevDMP = 0;
double prevDMN = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   double DMP1 = ADX.Plus(1);
   double DMN1 = ADX.Minus(1);
   double DMP0 = ADX.Plus(0);
   double DMN0 = ADX.Minus(0);
   double Strength = ADX.Main(0);

//--- Detect DM+/- Crossover.
   if(DMP1 < DMN1 && DMP0 > DMN0)
      trend = BULLISH_TREND;
   else
      if(DMP1 > DMN1 && DMP0 < DMN0)
         trend = BEARISH_TREND;
      else
         trend = NONE_TREND;

   indicators.Refresh();
   xauSymbol.RefreshRates();

   double sl, tp, sar, tmp;

//--- Trailing Stop / Profit
   if(PositionsTotal())
     {
      //--- per 15 minutes check SAR again.
      ulong seconds = TimeCurrent();
      if(seconds % 900)
         return ;

      //--- Close Position while Direction changed.
      position.SelectByIndex(0);
      ENUM_POSITION_TYPE positionType = position.PositionType();

      bool toUpdate = false;

      sl = position.StopLoss();
      tp = position.TakeProfit();

      sar = NormalizeDouble(sar, _Digits);

      switch(positionType)
        {
         case POSITION_TYPE_SELL:
            if(trailing.CheckTrailingStopShort(&position, sar, tmp))
              {
               if(sl != sar)
                 {
                  sl = sar;
                  toUpdate = true;
                 }
              }
            else
              {
               if(tp != tmp)
                 {
                  tp = tmp;
                  toUpdate = true;
                 }
              }

            break;
         case POSITION_TYPE_BUY:
            if(trailing.CheckTrailingStopLong(&position, sar, tmp))
              {
               if(sl != sar)
                 {
                  sl = sar;
                  toUpdate = true;
                 }

              }
            else
              {
               if(tp != tmp)
                 {
                  tp = tmp;
                  toUpdate = true;
                 }
              }
            break;
        }

      if(toUpdate)
        {
         ulong ticket;
         const string name = xauSymbol.Name();

         for(int count = PositionsTotal(); count > 0; count --)
           {
            position.SelectByIndex(count - 1);
            ticket = position.Ticket();
            if(position.Symbol() == name &&
               trade.PositionModify(ticket, sl, tp))
              {
               Print("Update (" + ticket + ") StopLoss: " + sl + " / TakeProfit: " + tp);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceOrder(string action, double StopLoss)
  {
   const double lot = orderLot;

   MqlTick latest_price;
   SymbolInfoTick(_Symbol, latest_price);

   Print("Lot: ", lot);
   Print("StopLoss: ", StopLoss);
   Print("Action: ", action);

// Dry-Run only for debugging.
   if(InpDryRun)
      return ;

   if(action == SELL_ORDER)
     {
      if(PositionsTotal() == 0)
        {
         trade.Sell(lot, NULL, 0, StopLoss, 0, "Bearish Sell at " + latest_price.ask);
         Print("--------------------");
         Print(">> Sell " + lot + " at " + latest_price.bid + ", sl: " + StopLoss);
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
         trade.Buy(lot, NULL, 0, StopLoss, 0, "Bullish Buy at " + latest_price.bid);
         Print("--------------------");
         Print(">> Buy " + lot + " at " + latest_price.ask + ", sl: " + StopLoss);
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

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
