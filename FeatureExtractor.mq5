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
input bool     InpVerbose=false;
input bool     InpDryRun=false;
input int      InpBackTrackBars = 96;

input bool     InpSendTick=false;
input string   agentCallback = "http://127.0.0.1/";

input int      bollMALength = 60;   // based on M5.

//--- misc. variables
string   HttpHeaders = "content-type: application/json\r\n";

//--- A/D% Indicator
int adpHandle;

double ADPercentBuffer[];

//--- Bollinger Band% Indicator
int bollPercentHandle;

double BBPercentBuffer[];
double SqueezeRateBuffer[];
double MiddleLineBuffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bollinger Band Indicator
   /*
      bollingerHandle = iBands(_Symbol, PERIOD_M1, bollMALength, 0, 2, PRICE_CLOSE);
      if(bollingerHandle == INVALID_HANDLE)
        {
         PrintFormat("Failed to create handle of the iBands indicator for the symbol, code %d", GetLastError());
         return (INVALID_HANDLE);
        }
   */

//--- Bollinger Band% Indicator
   bollPercentHandle = iCustom(_Symbol, PERIOD_M5, "PercentBB");
   if(bollPercentHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the BB% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(BBPercentBuffer, true);
   ArraySetAsSeries(SqueezeRateBuffer, true);
   ArraySetAsSeries(MiddleLineBuffer, true);

//--- Accumlation / Distribution % Indicator
   adpHandle = iCustom(_Symbol, PERIOD_M5, "PercentAD");
   if(adpHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the A/D% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(ADPercentBuffer, true);

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
   string resultHeaders;
   char post[], result[];

//--- Calculate OHLC features.
   double open = iOpen(_Symbol, PERIOD_M5, 1);
   double high = iHigh(_Symbol, PERIOD_M5, 1);
   double low  = iLow(_Symbol, PERIOD_M5, 1);
   double close= iClose(_Symbol, PERIOD_M5, 1);

//--- Retrieve A/D% Indicator Data
   CopyBuffer(adpHandle, 0, 0, InpBackTrackBars, ADPercentBuffer);

//--- Retrieve BB% Indicator Data
   CopyBuffer(bollPercentHandle, 0, 0, InpBackTrackBars, BBPercentBuffer);
   CopyBuffer(bollPercentHandle, 1, 0, InpBackTrackBars, SqueezeRateBuffer);
   CopyBuffer(bollPercentHandle, 2, 0, InpBackTrackBars, MiddleLineBuffer);

//--- Latest Price.
   MqlTick latest_price;
   SymbolInfoTick(_Symbol, latest_price);

//--- Convert to JSON format.
   string jsonString = "{" +
//--- OHCL
                       "\"o\":" + open   + "," +
                       "\"h\":" + high   + "," +
                       "\"c\":" + close  + "," +
                       "\"l\":" + low    + "," +
//--- latest price
                       "\"lp\":" + latest_price.last + "," +
                       "\"dt\":" + (uint)latest_price.time + "," +
//--- BB% + S%
                       "\"bp\":" + BBPercentBuffer[0]     + "," +
                       "\"sr\":" + SqueezeRateBuffer[0]   + "," +
//--- A/D%
                       "\"adp\":" + ADPercentBuffer[0]    +
                       "}";

//--- Post to databank server.

   if(!InpSendTick)
      return ;

//--- 字串最後以 0 結尾，會導致 JSON.parse() 失敗。
//--- 因此要指定字串長度，避免最後面的 null character 也存入陣列。
   StringToCharArray(jsonString, post, 0, StringLen(jsonString));
   if(InpVerbose)
      Print("JSON: " + jsonString);

   int res = WebRequest("POST", agentCallback + "mt/tick/", HttpHeaders, 500, post, result, resultHeaders);
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
            if(InpVerbose)
               Print(CharArrayToString(result));
           }
         else
           {
            CJAVal jv;
            jv.Deserialize(result);

            //double stoploss = jv["sl"].ToDbl();
            //const double lot = orderLot ? orderLot : jv["l"].ToDbl();
            //const string action = jv["a"].ToStr();
            //const bool addition = jv["add"].ToBool();

            // Dry-Run only for debugging.
            if(InpDryRun)
               return ;
           }
        }
      else
         PrintFormat("Downloading failed, error code %d",res);
     }
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| URL Encoder function                                             |
//+------------------------------------------------------------------+
string urlEncode(string value)
  {
   int len = StringLen(value);
   string encodedValue = "";
   uchar characters[];
   StringToCharArray(value,characters);
   for(int i = 0; i<len ; i++)
     {
      encodedValue += StringFormat("%%%02x", characters[i]);
     }
   return encodedValue;
  }
//+------------------------------------------------------------------+
