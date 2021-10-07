//+------------------------------------------------------------------+
//|                                                  JinmonAgent.mq5 |
//|                                         Lex Yang @ Jinmon Island |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Lex Yang @ Jinmon Island"
#property link      ""
#property version   "1.00"

#include <JAson.mqh>
#include <MovingAverages.mqh>

//--- input parameters
input long     order_magic = 55555;

input double   additionLot=0;
input double   slDelta=0;
input double   orderLot=0;
input bool     verbose=false;
input bool     dryRun=false;
input string   agentCallback = "http://127.0.0.1/";

input int      obvFastMALength = 50;
input int      obvSlowMALength = 150;

input int      macdFast = 60;
input int      macdSlow = 130;
input int      macdSignal = 45;

input int      bollMALength = 390;

//--- misc. variables

//--- OBV Indicator
int obvHandle;
double OBVBuffer[];
double obvFastMABuffer[];
double obvSlowMABuffer[];

//--- MACD Indicator
int macdHandle;
double MACDBuffer[];
double SignalBuffer[];

//--- Bollinger Band Indicator
int bollHandle;

double UpperBuffer[];
double LowerBuffer[];
double BaseBuffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   obvHandle = iOBV(_Symbol, PERIOD_M5, VOLUME_TICK);
   if(obvHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the iOBV indicator for the symbol, code %d", GetLastError());
      return (INIT_FAILED);
     }

   macdHandle = iMACD(_Symbol, PERIOD_M1, macdFast, macdSlow, macdSignal, PRICE_CLOSE);
   if(macdHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the iMACD indicator for the symbol, code %d", GetLastError());
      return (INIT_FAILED);
     }

   bollHandle = iBands(_Symbol, PERIOD_M1, bollMALength, 0, 2, PRICE_CLOSE);
   if(bollHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the iBands indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
double CalibrateOHLC(double p)
  {
   return (p - 1000) / 1000;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   string cookie = NULL, headers;
   char post[], result[];

//--- Calculate OHLC features.
   double open = CalibrateOHLC(iOpen(_Symbol, PERIOD_M5, 1));
   double high = CalibrateOHLC(iHigh(_Symbol, PERIOD_M5, 1)) - open;
   double low  = CalibrateOHLC(iLow(_Symbol, PERIOD_M5, 1)) - open;
   double close= CalibrateOHLC(iClose(_Symbol, PERIOD_M5, 1)) - open;

//--- Calculate OBV features.
   if(CopyBuffer(obvHandle, 0, 1, obvSlowMALength * 2, OBVBuffer) < 0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iOBV indicator, error code %d",GetLastError());
      return ;
     }

   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, obvFastMALength, OBVBuffer, obvFastMABuffer);
   ExponentialMAOnBuffer(rates_total, prev_calculated, 0, obvSlowMALength, OBVBuffer, obvSlowMABuffer);

//--- Calculate MACD features.
   CopyBuffer(macdHandle, 0, 0, 1, MACDBuffer);
   CopyBuffer(macdHandle, 1, 0, 1, SignalBuffer);
   double macd = MACDBuffer[0];
   double signal = SignalBuffer[0];
   
//--- Calculate Bollinger Band features.
   CopyBuffer(bollHandle, 0, 0, 1, BaseBuffer);
   CopyBuffer(bollHandle, 1, 0, 1, UpperBuffer);
   CopyBuffer(bollHandle, 2, 0, 1, LowerBuffer);
   double base = CalibrateOHLC(BaseBuffer[0]);
   double upper = CalibrateOHLC(UpperBuffer[0]) - close;
   double lower = close - CalibrateOHLC(LowerBuffer[0]);
   
//--- Post to databank server.
   int res = WebRequest("POST", agentCallback + "mt/tick/", cookie, NULL, 500, post, 0, result, headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address
      //MessageBox("Add the address to the list of allowed URLs on tab 'Expert Advisors'","Error",MB_ICONINFORMATION);
      Print("Add the address [", agentCallback, "] to the list of allowed URLs on tab 'Expert Advisors'");
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

            double stoploss = jv["sl"].ToDbl();
            const double lot = orderLot ? orderLot : jv["l"].ToDbl();
            const string action = jv["a"].ToStr();
            const bool addition = jv["add"].ToBool();

            MqlTick latest_price;
            SymbolInfoTick(_Symbol, latest_price);

            // Dry-Run only for debugging.
            if(dryRun)
               return ;
           }
        }
      else
         PrintFormat("Downloading failed, error code %d",res);
     }
  }

//+------------------------------------------------------------------+
