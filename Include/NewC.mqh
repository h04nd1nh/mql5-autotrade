//+------------------------------------------------------------------+
//|                                                         NewC.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

bool IsNewCandle()
  {
   static int BarsOnChart=0;
   if(Bars(Symbol(),PERIOD_CURRENT) == BarsOnChart)
      return (false);
   BarsOnChart = Bars(Symbol(),PERIOD_CURRENT);
   return(true);
  }
