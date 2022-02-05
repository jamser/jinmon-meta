//+------------------------------------------------------------------+
//| Class CiASI.                                                     |
//| Purpose: Class of the "Accumulative Swing Index                  |
//|          by Welles Wilder" indicator.                            |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
#include <Indicators\Indicators.mqh>

class CiASI : public CIndicator
  {
protected:
   double            m_t_point;

public:
                     CiASI(void);
                    ~CiASI(void);
   //--- methods of access to protected data
   int               TPoint(void) const { return(m_t_point); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const double t_point);
   //--- methods of access to indicator data
   double            Main(const int index) const;
   double            SwingPoint(const int index) const;

   //--- method of identifying
   virtual int       Type(void) const { return(IND_ADXW); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const double t_point);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiASI::CiASI(void) : m_t_point(0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiASI::~CiASI(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Average Directional Index by Welles Wilder"    |
//+------------------------------------------------------------------+
bool CiASI::Create(const string symbol,const ENUM_TIMEFRAMES period,const double t_point)
  {
//--- check history
   if(!SetSymbolPeriod(symbol,period))
      return(false);
//--- create
   m_handle=iCustom(symbol,period,"ASI");
//--- check result
   if(m_handle==INVALID_HANDLE)
      return(false);
//--- indicator successfully created
   if(!Initialize(symbol,period,t_point))
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
bool CiASI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiASI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const double t_point)
  {
   if(CreateBuffers(symbol,period,2))
     {
      //--- string of status of drawing
      m_name  ="ASI";
      m_status="("+symbol+","+PeriodDescription()+","+IntegerToString(t_point)+") H="+IntegerToString(m_handle);
      //--- save settings
      m_t_point=t_point;
      //--- create buffers
      ((CIndicatorBuffer*)At(0)).Name("SI");
      ((CIndicatorBuffer*)At(1)).Name("SP");
      //--- ok
      return(true);
     }
//--- error
   return(false);
  }
//+------------------------------------------------------------------+
//| Access to Main buffer of "Accumulative Swing Index               |
//|                           by Welles Wilder"                      |
//+------------------------------------------------------------------+
double CiASI::Main(const int index) const
  {
   CIndicatorBuffer *buffer=At(0);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
//+------------------------------------------------------------------+
//| Access to Minus buffer of "Accumulative Swing Index              |
//|                            by Welles Wilder"                     |
//+------------------------------------------------------------------+
double CiASI::SwingPoint(const int index) const
  {
   CIndicatorBuffer *buffer=At(1);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }