//+------------------------------------------------------------------+
//| Class CiADXR.                                               |
//| Purpose: Class of the "Average Directional Index                 |
//|          by Welles Wilder" indicator.                            |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
#include <Indicators\Indicators.mqh>

class CiADXR : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiADXR(void);
                    ~CiADXR(void);
   //--- methods of access to protected data
   int               MaPeriod(void) const { return(m_ma_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   double            Main(const int index) const;
   double            Plus(const int index) const;
   double            Minus(const int index) const;
   double            ADXR(const int index) const;
   double            ATR(const int index) const;

   //--- method of identifying
   virtual int       Type(void) const { return(IND_ADXW); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiADXR::CiADXR(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiADXR::~CiADXR(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Average Directional Index by Welles Wilder"    |
//+------------------------------------------------------------------+
bool CiADXR::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
//--- check history
   if(!SetSymbolPeriod(symbol,period))
      return(false);
//--- create
   m_handle=iCustom(symbol,period,"CustomADXW");
//--- check result
   if(m_handle==INVALID_HANDLE)
      return(false);
//--- indicator successfully created
   if(!Initialize(symbol,period,ma_period))
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
bool CiADXR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiADXR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   if(CreateBuffers(symbol,period,5))
     {
      //--- string of status of drawing
      m_name  ="ADXWilder";
      m_status="("+symbol+","+PeriodDescription()+","+IntegerToString(ma_period)+") H="+IntegerToString(m_handle);
      //--- save settings
      m_ma_period=ma_period;
      //--- create buffers
      ((CIndicatorBuffer*)At(0)).Name("MAIN_LINE");
      ((CIndicatorBuffer*)At(1)).Name("PLUS_LINE");
      ((CIndicatorBuffer*)At(2)).Name("MINUS_LINE");
      ((CIndicatorBuffer*)At(3)).Name("ADXR");
      ((CIndicatorBuffer*)At(4)).Name("ATR");
      //--- ok
      return(true);
     }
//--- error
   return(false);
  }
//+------------------------------------------------------------------+
//| Access to Main buffer of "Average Directional Index              |
//|                           by Welles Wilder"                      |
//+------------------------------------------------------------------+
double CiADXR::Main(const int index) const
  {
   CIndicatorBuffer *buffer=At(0);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
//+------------------------------------------------------------------+
//| Access to Plus buffer of "Average Directional Index              |
//|                           by Welles Wilder"                      |
//+------------------------------------------------------------------+
double CiADXR::Plus(const int index) const
  {
   CIndicatorBuffer *buffer=At(1);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
//+------------------------------------------------------------------+
//| Access to Minus buffer of "Average Directional Index             |
//|                            by Welles Wilder"                     |
//+------------------------------------------------------------------+
double CiADXR::Minus(const int index) const
  {
   CIndicatorBuffer *buffer=At(2);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
//+------------------------------------------------------------------+
//| Access to ADXR buffer of "Average Directional Index              |
//|                            by Welles Wilder"                     |
//+------------------------------------------------------------------+
double CiADXR::ADXR(const int index) const
  {
   CIndicatorBuffer *buffer=At(3);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
//+------------------------------------------------------------------+
//| Access to ATR buffer of "Average Directional Index               |
//|                            by Welles Wilder"                     |
//+------------------------------------------------------------------+
double CiADXR::ATR(const int index) const
  {
   CIndicatorBuffer *buffer=At(4);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }