//+------------------------------------------------------------------+
//|                                                  JinmonAgent.mq5 |
//|                                         Lex Yang @ Jinmon Island |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex Yang @ Jinmon Island"
#property link      ""
#property version   "1.00"

#include <JAson.mqh>

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

//--- input parameters
input long     order_magic = 55555;

input double   orderLot=0;
input int      pollingInterval=3;
input bool     verbose=false;
input string   agentCallback = "http://127.0.0.1/";

//--- Trade variables.
const string   SELL_ORDER = "sell";
const string   BUY_ORDER = "buy";
const string   CLOSE_ORDER = "close";

CPositionInfo position;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(pollingInterval);

   trade.SetExpertMagicNumber(order_magic);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(false);
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

  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   string cookie = NULL, headers;
   char post[], result[];

   int res = WebRequest("POST", agentCallback + "mt/poll/", cookie, NULL, 500, post, 0, result, headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address
      MessageBox("Add the address to the list of allowed URLs on tab 'Expert Advisors'","Error",MB_ICONINFORMATION);
     }
   else
     {
      if(res==200)
        {
         if(ArraySize(result) == 2)
           {
            if(verbose)
               Print("NA");
           }
         else
           {
            CJAVal jv;
            jv.Deserialize(result);

            const double lot = orderLot ? orderLot : jv["l"].ToDbl();
            const double stoploss = jv["sl"].ToDbl();
            const string action = jv["a"].ToStr();

            Print("Lot: ", lot);
            Print("StopLoss: ", stoploss);
            Print("Action: ", action);

            if(action == CLOSE_ORDER)
               CloseOrder();

            if(action == SELL_ORDER)
              {
               if(PositionsTotal() == 0)
                  trade.Sell(lot, NULL, 0, stoploss);
               else
                  if(position.PositionType() == POSITION_TYPE_BUY)
                     CloseOrder();
              }

            if(action == BUY_ORDER)
              {
               if(PositionsTotal() == 0)
                  trade.Buy(lot, NULL, 0, stoploss);
               else
                  if(position.PositionType() == POSITION_TYPE_SELL)
                     CloseOrder();
              }
           }
        }
      else
         PrintFormat("Downloading failed, error code %d",res);
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
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong PlaceOrder(string cmd, double volume, double stoploss)
  {
//--- MQL5
   MqlTradeRequest request= {};
   request.action = TRADE_ACTION_DEAL;
   request.magic = order_magic;
   request.symbol = _Symbol;
   request.type = (cmd == SELL_ORDER ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   request.volume = volume;
   request.sl = stoploss;

   MqlTradeResult result = {};
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
bool CloseOrder()
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

//+------------------------------------------------------------------+
