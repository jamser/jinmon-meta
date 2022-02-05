//+------------------------------------------------------------------+
//| Class CiADP.                                                     |
//| Purpose: Class of the "Accumalation / Distribution % Index       |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
#include <Indicators\Indicators.mqh>

class CiADP : public CIndicator
  {
protected:

public:
                     CiADP(void);
                    ~CiADP(void);
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods of access to indicator data
   double            Main(const int index) const;

   //--- method of identifying
   virtual int       Type(void) const { return(IND_AD); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiADP::CiADP(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiADP::~CiADP(void)
  {
  }
bool CiADP::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
//--- check history
   if(!SetSymbolPeriod(symbol,period))
      return(false);
//--- create
   m_handle=iCustom(symbol,period,"PercentAD");
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
bool CiADP::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiADP::Initialize(const string symbol,const ENUM_TIMEFRAMES period)
  {
   if(CreateBuffers(symbol,period,1))
     {
      //--- string of status of drawing
      m_name  ="ADP";
      m_status="("+symbol+","+PeriodDescription()+ ") H="+IntegerToString(m_handle);
      //--- create buffers
      ((CIndicatorBuffer*)At(0)).Name("A/D%");
      //--- ok
      return(true);
     }
//--- error
   return(false);
  }
//+------------------------------------------------------------------+
double CiADP::Main(const int index) const
  {
   CIndicatorBuffer *buffer=At(0);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }