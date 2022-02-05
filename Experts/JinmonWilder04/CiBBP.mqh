//+------------------------------------------------------------------+
//| Class CiBBP.                                                     |
//| Purpose: Class of the "Bollinger Band% Index                     |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
#include <Indicators\Indicators.mqh>

class CiBBP : public CIndicator
  {
protected:

public:
                     CiBBP(void);
                    ~CiBBP(void);
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods of access to indicator data
   double            BBP(const int index) const;
   double            SR(const int index) const;
   double            Width(const int index) const;

   //--- method of identifying
   virtual int       Type(void) const { return(IND_BANDS); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiBBP::CiBBP(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiBBP::~CiBBP(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Average Directional Index by Welles Wilder"    |
//+------------------------------------------------------------------+
bool CiBBP::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
//--- check history
   if(!SetSymbolPeriod(symbol,period))
      return(false);
//--- create
   m_handle=iCustom(symbol,period,"PercentBB");
//--- check result
   if(m_handle==INVALID_HANDLE)
      return(false);
//--- indicator successfully created
   if(!Initialize(symbol,period))
     {
      //--- initialization failed
      IndicatorRelease(m_handle);
      m_handle=INVALID_HANDLE;
      return(false);
     }
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiBBP::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiBBP::Initialize(const string symbol,const ENUM_TIMEFRAMES period)
  {
   if(CreateBuffers(symbol,period,6))
     {
      //--- string of status of drawing
      m_name  ="BBP";
      m_status="("+symbol+","+PeriodDescription()+ ") H="+IntegerToString(m_handle);
      //--- create buffers
      ((CIndicatorBuffer*)At(0)).Name("BB");
      ((CIndicatorBuffer*)At(1)).Name("BB_Color");
      ((CIndicatorBuffer*)At(2)).Name("SR");
      ((CIndicatorBuffer*)At(3)).Name("SR_Color");
      ((CIndicatorBuffer*)At(4)).Name("BB_ML");
      ((CIndicatorBuffer*)At(5)).Name("BB_UL");
      //--- ok
      return(true);
     }
//--- error
   return(false);
  }
//+------------------------------------------------------------------+
double CiBBP::BBP(const int index) const
  {
   CIndicatorBuffer *buffer=At(0);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
//+------------------------------------------------------------------+
double CiBBP::SR(const int index) const
  {
   CIndicatorBuffer *buffer=At(2);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
//+------------------------------------------------------------------+
double CiBBP::Width(const int index) const
  {
   CIndicatorBuffer *ml=At(4);
   CIndicatorBuffer *ul=At(5);
//--- check
   if(ml==NULL || ul==NULL)
      return(EMPTY_VALUE);
//---
   return (ul.At(index) - ml.At(index)) * 2;
  }