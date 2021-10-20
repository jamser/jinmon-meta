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

input double   additionLot=0;
input double   slDelta=0;
input double   orderLot=0;

//--- Trade variables.
const string   GOTO_TIME = "goto";
const string   SELL_ORDER = "sell";
const string   BUY_ORDER = "buy";
const string   CLOSE_ORDER = "close";

CPositionInfo position;
CTrade trade;

//--- input parameters
input string   InpListName="";            // List to save features.
input bool     InpVerbose=false;          // Verbose
input bool     InpDryRun=false;           // Dry Run
input bool     InpSimulation = false;     // Simulated Tick
input int      InpBackTrackBars = 96;

input bool     InpPolling = true;         // Polling Event
input bool     InpSendIndicator = true;   // Send Indicator to Server
input bool     InpSendTick=false;         // Send Tick to Server
input string   agentCallback = "https://192.168.179.1/";

input ENUM_TIMEFRAMES   p1TimeFrame = PERIOD_M1;
input ENUM_TIMEFRAMES   p2TimeFrame = PERIOD_M5;

//--- misc. variables
bool     isTestMode = false;
bool     enablePolling;
bool     enableSimulation;
bool     enableSendTick;
int      backTrackBars = 0;
int      extractPeriod = 0;

string   listToken = "";
int      fileHandle = INVALID_HANDLE;
string   HttpHeaders = "content-type: application/json\r\n";


uint     p1CountDown = 60;
uint     p2CountDown = 300;
uint     timerTick = 0;

enum ENUM_AGENT_ACTION
  {
   INIT_P1_INDICATOR = 0,
   INIT_P2_INDICATOR = 1,
   GOTO_DATETIME = 2,
   NONE_ACTION = -1,
  };

//--- A/D% Indicator
int p1ADpHandle;
int p2ADpHandle;

double p1ADPercentBuffer[];
double p2ADPercentBuffer[];

//--- Bollinger Band% Indicator
int p1BollPercentHandle;
int p2BollPercentHandle;

double p1BBPercentBuffer[];
double p1SqueezeRateBuffer[];
double p1MiddleLineBuffer[];

double p2BBPercentBuffer[];
double p2SqueezeRateBuffer[];
double p2MiddleLineBuffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   enablePolling = InpPolling;
   enableSimulation = InpSimulation;
   enableSendTick = InpSendTick;
   backTrackBars = InpBackTrackBars;

//--- P1 Bollinger Band% Indicator
   p1BollPercentHandle = iCustom(_Symbol, p1TimeFrame, "PercentBB");
   if(p1BollPercentHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the BB% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p1BBPercentBuffer, true);
   ArraySetAsSeries(p1SqueezeRateBuffer, true);
   ArraySetAsSeries(p1MiddleLineBuffer, true);

//--- P1 Accumlation / Distribution % Indicator
   p1ADpHandle = iCustom(_Symbol, p1TimeFrame, "PercentAD");
   if(p1ADpHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the A/D% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p1ADPercentBuffer, true);

//--- P2 Bollinger Band% Indicator
   p2BollPercentHandle = iCustom(_Symbol, p2TimeFrame, "PercentBB");
   if(p2BollPercentHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the BB% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p2BBPercentBuffer, true);
   ArraySetAsSeries(p2SqueezeRateBuffer, true);
   ArraySetAsSeries(p2MiddleLineBuffer, true);

//--- P2 Accumlation / Distribution % Indicator
   p2ADpHandle = iCustom(_Symbol, p2TimeFrame, "PercentAD");
   if(p2ADpHandle == INVALID_HANDLE)
     {
      PrintFormat("Failed to create handle of the A/D% indicator for the symbol, code %d", GetLastError());
      return (INVALID_HANDLE);
     }
   ArraySetAsSeries(p2ADPercentBuffer, true);

//--- Initialize Buffers
   UpdateP1Buffer();
   UpdateP2Buffer();

//---
   if(InpListName == "")
      MessageBox("Please assign List Name to enable Feature Extraction !");
   else
     {
      string fileName = "Features\\" + InpListName + ".json";
      Print("Root Folder : " + TerminalInfoString(TERMINAL_DATA_PATH));
      Print("Open file : " + fileName);

      fileHandle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI, 0);
      if(fileHandle == INVALID_HANDLE)
         Print("Failed to Open File !!!");
      else
         FileWriteString(fileHandle, "[");

      string jsonString = "{\"name\": \"" + InpListName + "\"}";
      CJAVal result;
      Print("Create List Command : " + jsonString);

      /*
            PostToServer("mt/create-list", jsonString, result);
            listToken = result["r"].ToStr();
            Print("Access Token : " + listToken);
      */
      if(listToken != "" || fileHandle != INVALID_HANDLE)
        {
         Print("Start Testing Mode ...");
         isTestMode = true;

         // Disable following functions:
         Print("[Test Mode] Disable Polling / SimuFlation / Send Tick");
         enablePolling = false;
         enableSimulation = false;
         enableSendTick = false;
         backTrackBars = 1;

         switch(p2TimeFrame)
           {
            case PERIOD_M5:
               extractPeriod = 5 * 60;
               break;
            case PERIOD_M15:
               extractPeriod = 15 * 60;
               break;
            case PERIOD_H1:
               extractPeriod = 60 * 60;
               break;
           }
        }
     }

//--- Simulation Ticking by Timer.
   if(enablePolling || enableSimulation || enableSendTick)
     {
      EventSetTimer(1);
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(fileHandle != INVALID_HANDLE)
     {
      FileSeek(fileHandle, -2, SEEK_CUR);
      FileWriteString(fileHandle, "]");
      Print("Flush ...");
      FileFlush(fileHandle);
      Print("Close file !");
      FileClose(fileHandle);
     }
   if(listToken != "")
     {
      string jsonString = "{\"token\":\"" + listToken + "\"}";
      CJAVal result;

      /*
            PostToServer("mt/close-list", jsonString, result);
            Print("Release List Table ...");
      */
     }

   isTestMode = false;

   EventKillTimer();
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
int prevExtractTime = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(isTestMode)
     {
      //--- Latest Price.
      MqlTick latest_price;
      SymbolInfoTick(_Symbol, latest_price);

      int trimmedTime = latest_price.time / extractPeriod;
      if(prevExtractTime == trimmedTime)
         return ;

      prevExtractTime = trimmedTime;
      UpdateP2Buffer();

      string jsonTickData = ConvertToJSON(p2TimeFrame, latest_price, p2BBPercentBuffer, p2SqueezeRateBuffer, p2ADPercentBuffer);
      string jsonString = "{\"toekn\":" + listToken + ", \"item\": " + jsonTickData + "}";

      uint bytes = FileWriteString(fileHandle, jsonTickData + ",\n");
      if(fileHandle != INVALID_HANDLE && InpVerbose)
        {
         Print("Write Bytes: " + bytes);
        }

      if(listToken == "")
        {
         if(InpVerbose)
            Print("No Access Token of List, CAN NOT send feature back to server !!!");
         return ;
        }

      CJAVal result;

      if(PostToServer("mt/rpush", jsonString, result) == false)
        {
         Print("Failed to send feature to server !!!");
        }
     }

   if(enableSendTick)
      SendTick("mt/tick", p1TimeFrame, p2BBPercentBuffer, p2SqueezeRateBuffer, p2ADPercentBuffer);

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(enablePolling)
     {
      ENUM_AGENT_ACTION action = Polling();
      switch(action)
        {
        }
     }

   if(enableSimulation)
      SendTick("mt/tick", p1TimeFrame, p1BBPercentBuffer, p1SqueezeRateBuffer, p1ADPercentBuffer);

//--- Phase 1 Update - 1 minute
   if(enableSendTick && (timerTick % p1CountDown == 0))
     {
      UpdateP1Buffer();
      SendTick("mt/p1", p1TimeFrame, p1BBPercentBuffer, p1SqueezeRateBuffer, p1ADPercentBuffer);
     }

//--- Phase 2 Update - 5 minutes
   if(enableSendTick && (timerTick % p2CountDown == 0))
     {
      UpdateP2Buffer();
      SendTick("mt/p2", p2TimeFrame, p2BBPercentBuffer, p2SqueezeRateBuffer, p2ADPercentBuffer);
     }

   timerTick ++;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CloseOrder()
  {
   int count = PositionsTotal();

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
ENUM_AGENT_ACTION Polling()
  {
//---
   string cookie = NULL, headers;
   char post[], result[];

   int res = WebRequest("POST", agentCallback + "mt/poll/", cookie, NULL, 500, post, 0, result, headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      Print("Add the address [", agentCallback, "] to the list of allowed URLs on tab 'Expert Advisors'");
     }
   else
     {
      if(res==200)
        {
         if(ArraySize(result) == 2)
           {
            if(InpVerbose)
               Print("NA");
           }
         else
           {
            CJAVal jv;
            jv.Deserialize(result);

            const string action = jv["a"].ToStr();

            if(action == GOTO_TIME)
              {
               const long dt = jv["dt"].ToInt();
               int shift = iBarShift(_Symbol, PERIOD_CURRENT, (datetime)(dt), false);

               if(ChartGetInteger(0, CHART_AUTOSCROLL))
                  ChartSetInteger(0, CHART_AUTOSCROLL, false);

               ChartNavigate(0, CHART_BEGIN, shift);

               Print("Goto Time "+ dt + " / shift: " + shift);
               return GOTO_DATETIME;
              }

            double stoploss = jv["sl"].ToDbl();
            const double lot = orderLot ? orderLot : jv["l"].ToDbl();
            const bool addition = jv["add"].ToBool();

            MqlTick latest_price;
            SymbolInfoTick(_Symbol, latest_price);

            if(stoploss == 0)
              {
               stoploss = (action == SELL_ORDER) ? (latest_price.ask + slDelta) : (latest_price.bid - slDelta);
              }

            Print("Lot: ", lot);
            Print("StopLoss: ", stoploss);
            Print("Action: ", action);

            // Dry-Run only for debugging.
            if(InpDryRun)
               return NONE_ACTION;

            if(action == CLOSE_ORDER)
               CloseOrder();

            if(action == SELL_ORDER)
              {
               if(PositionsTotal() == 0)
                 {
                  trade.Sell(lot, NULL, 0, stoploss);
                  Print("--------------------");
                  Print(">> Sell " + lot + " at " + latest_price.bid + ", sl: " + stoploss);
                  Print("--------------------");
                 }
               else
                  if(addition)
                    {
                     trade.Sell(additionLot, NULL, 0, stoploss);
                     Print("--------------------");
                     Print(">> Additional Sell " + additionLot + " at " + latest_price.bid + ", sl: " + stoploss);
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
                  trade.Buy(lot, NULL, 0, stoploss);
                  Print("--------------------");
                  Print(">> Buy " + lot + " at " + latest_price.ask + ", sl: " + stoploss);
                  Print("--------------------");
                 }
               else
                  if(addition)
                    {
                     trade.Buy(additionLot, NULL, 0, stoploss);
                     Print("--------------------");
                     Print(">> Additional Buy " + additionLot + " at " + latest_price.ask + ", sl: " + stoploss);
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
        }
      else
         PrintFormat("Downloading failed, error code %d",res);
     }

   return NONE_ACTION;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ConvertToJSON(ENUM_TIMEFRAMES timeframes, MqlTick& price, double &bbpBuffer[], double &srBuffer[], double &adpBuffer[])
  {
//--- Calculate OHLC features.
   double open = iOpen(_Symbol, timeframes, 0);
   double high = iHigh(_Symbol, timeframes, 0);
   double low  = iLow(_Symbol, timeframes, 0);
   double close= iClose(_Symbol, timeframes, 0);

//--- Convert to JSON format.
   string jsonString = "{" +
//--- OHCL
                       "\"o\":" + open   + "," +
                       "\"h\":" + high   + "," +
                       "\"c\":" + close  + "," +
                       "\"l\":" + low    + "," +
//--- latest price
                       "\"la\":" + price.ask         + "," +
                       "\"lb\":" + price.bid         + "," +
                       "\"ts\":" + (uint)price.time  + "," +
//--- BB% + S%
                       "\"bp\":" + bbpBuffer[0]       + "," +
                       "\"sr\":" + srBuffer[0]     + "," +
//--- A/D%
                       "\"adp\":" + adpBuffer[0]    +
                       "}";
   return jsonString;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateP1Buffer()
  {
//--- Retrieve BB% Indicator Data
   CopyBuffer(p1BollPercentHandle, 0, 0, InpBackTrackBars, p1BBPercentBuffer);
   CopyBuffer(p1BollPercentHandle, 1, 0, InpBackTrackBars, p1SqueezeRateBuffer);
   CopyBuffer(p1BollPercentHandle, 2, 0, InpBackTrackBars, p1MiddleLineBuffer);

//--- Retrieve A/D% Indicator Data
   CopyBuffer(p1ADpHandle, 0, 0, InpBackTrackBars, p1ADPercentBuffer);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateP2Buffer()
  {
//--- Retrieve BB% Indicator Data
   CopyBuffer(p2BollPercentHandle, 0, 0, InpBackTrackBars, p2BBPercentBuffer);
   CopyBuffer(p2BollPercentHandle, 1, 0, InpBackTrackBars, p2SqueezeRateBuffer);
   CopyBuffer(p2BollPercentHandle, 2, 0, InpBackTrackBars, p2MiddleLineBuffer);

//--- Retrieve A/D% Indicator Data
   CopyBuffer(p2ADpHandle, 0, 0, InpBackTrackBars, p2ADPercentBuffer);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SendTick(string apiPath, ENUM_TIMEFRAMES timeframes, double &bbpBuffer[], double &srBuffer[], double &adpBuffer[])
  {
   string resultHeaders;
   char post[], result[];

//--- Latest Price.
   MqlTick latest_price;
   SymbolInfoTick(_Symbol, latest_price);

   string jsonString = ConvertToJSON(timeframes, latest_price, bbpBuffer, srBuffer, adpBuffer);
//--- Post to databank server.

//--- 字串最後以 0 結尾，會導致 JSON.parse() 失敗。
//--- 因此要指定字串長度，避免最後面的 null character 也存入陣列。
   StringToCharArray(jsonString, post, 0, StringLen(jsonString));
   if(InpVerbose)
      Print("JSON: " + jsonString);

   int res = WebRequest("POST", agentCallback + apiPath, HttpHeaders, 500, post, result, resultHeaders);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
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
//|                                                                  |
//+------------------------------------------------------------------+
bool PostToServer(string apiPath, string postData, CJAVal& resultValue)
  {
   string cookie = NULL, headers;
   char post[], result[];
   bool  retValue = false;

   StringToCharArray(postData, post, 0, StringLen(postData));
   int res = WebRequest("POST", agentCallback + apiPath, HttpHeaders, 500, post, result, headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      Print("Add the address [", agentCallback, "] to the list of allowed URLs on tab 'Expert Advisors'");
     }
   else
     {
      if(res==200)
        {
         resultValue.Deserialize(result);
         retValue = true;
        }
      else
         PrintFormat("Downloading failed, error code %d",res);
     }

   return retValue;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool WriteToFile(string apiPath, string postData, CJAVal& resultValue)
  {
   string cookie = NULL, headers;
   char post[], result[];
   bool  retValue = false;

   StringToCharArray(postData, post, 0, StringLen(postData));
   int res = WebRequest("POST", agentCallback + apiPath, HttpHeaders, 500, post, result, headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      Print("Add the address [", agentCallback, "] to the list of allowed URLs on tab 'Expert Advisors'");
     }
   else
     {
      if(res==200)
        {
         resultValue.Deserialize(result);
         retValue = true;
        }
      else
         PrintFormat("Downloading failed, error code %d",res);
     }

   return retValue;
  }
//+------------------------------------------------------------------+
