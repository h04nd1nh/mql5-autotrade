//+------------------------------------------------------------------+
//|                                                   EURUSD_M15.mq5 |
//|                                  Copyright 2024, h04nd1nh        |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh> 

CTrade trade; 

//--- global variables
int bands_period= 10;        
double deviation= 2;
int magicNumber1 = 123456;
int magicNumber2 = 654321;
int BandsHandle;                   // Bolinger Bands handle
int Ema50Handle;   
int Ema200Handle;                 // DEMA handle
double BBUp[],BBLow[];   // dynamic arrays for numerical values of Bollinger Bands
double ema50[], ema200[]; 
ulong lastOrderTicket;
double lastOrderBid;
double lastOrderAsk;
bool isOpenBuy = false;
bool isOpenSell = false;
bool isOpenBuyDCA = false;
bool isOpenSellDCA = false;
string lastCloseReason = "TP";
   

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    BandsHandle = iBands(_Symbol,PERIOD_M5,bands_period,0,deviation,PRICE_CLOSE);
    Ema50Handle = iMA(_Symbol,PERIOD_M5,50,0,MODE_EMA,PRICE_CLOSE);
    Ema200Handle = iMA(_Symbol,PERIOD_M5,200,0,MODE_EMA,PRICE_CLOSE);  
    if((BandsHandle<0) || (Ema50Handle<0) || ((Ema200Handle<0)))
     {
      Alert("Error in creation of indicators - error: ",GetLastError(),"!!");
      return(-1);
     }
    return(0);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
     IndicatorRelease(BandsHandle);
     IndicatorRelease(Ema50Handle);
     IndicatorRelease(Ema200Handle);
   
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
  {
      ArraySetAsSeries(BBUp,true);
      ArraySetAsSeries(BBLow,true);
      ArraySetAsSeries(ema50,true);
      ArraySetAsSeries(ema200,true);
      
      if(CopyBuffer(BandsHandle,1,0,1,BBUp)<0 || CopyBuffer(BandsHandle,2,0,1,BBLow)<0) {
         Alert("Error copying Bollinger Bands indicator Buffers - error:",GetLastError(),"!!");
         return;
      }
      
      if(CopyBuffer(Ema50Handle,0,0,10,ema50)<0 || CopyBuffer(Ema200Handle,0,0,10,ema200)<0) {
         Alert("Error copying Bollinger Bands indicator Buffers - error:",GetLastError(),"!!");
         return;
      }
      
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);   // Ask price (buy open)
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);   // Bid price (sell open
      double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT); //  Calculate pip size
      int spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      
      bool buyFirstOpenCondition = (spread <=10 && checkTrend() == "UP_TREND" && bid <= BBLow[0] + 10*pipSize && (lastCloseReason == "TP" || bid >= ema50[0]));
      bool sellFirstOpenCondition = (spread <=10 && checkTrend() == "DOWN_TREND" && bid >= BBUp[0] - 10*pipSize && (lastCloseReason == "TP" || bid <= ema50[0]));
      double lastOrderAskTemp = lastOrderAsk;
      double lastOrderBidTemp = lastOrderBid;
      bool buySecondOpenCondition = (spread <=10 && isOpenBuy && !isOpenBuyDCA && bid <= (lastOrderAskTemp - 150*pipSize));
      bool sellSecondOpenCondition = (spread <=10 && isOpenSell && !isOpenSellDCA && bid >= (lastOrderBidTemp + 150*pipSize));
      bool buyStoplossBE = (isOpenBuy && bid >= (lastOrderAskTemp + 60*pipSize));
      bool sellStoplossBE = (isOpenSell && bid <= (lastOrderBidTemp - 60*pipSize));
      
      if (buyFirstOpenCondition) {
         LongPositionOpen();
      }
      
      if (sellFirstOpenCondition) {
         ShortPositionOpen();
      }
      
      if (buySecondOpenCondition) {
         LongDCAPositionOpen();
      }
      
      if (sellSecondOpenCondition) {
         ShortDCAPositionOpen();
      }
      
      if (buyStoplossBE) {
         int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         double sl = lastOrderAskTemp + 25*pipSize;
         double tp = lastOrderAskTemp + 100*pipSize;
         trade.PositionModify(PositionGetTicket(0),NormalizeDouble(sl,digits),NormalizeDouble(tp,digits)); 
      }
      
      if (sellStoplossBE) {
         int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         double sl = lastOrderBidTemp - 25*pipSize;
         double tp = lastOrderBidTemp - 100*pipSize;
         trade.PositionModify(PositionGetTicket(0),NormalizeDouble(lastOrderAskTemp - 25*pipSize,digits),NormalizeDouble(lastOrderAskTemp - 100*pipSize,digits));
      }
  }
//+------------------------------------------------------------------+

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{ 
   if (trans.symbol == _Symbol) {
      if (CheckIfPositionClosed(trans.position, trans.type)) {
         isOpenBuy = false;
         isOpenSell = false;
         isOpenBuyDCA = false;
         isOpenSellDCA = false;
      }
   }

}

string checkTrend() {
   bool isUptrend = true;
   bool isDowntrend = true;
   for (int i = 0; i < 10; i++) {
      if (ema50[i] < ema200[i]) {
         isUptrend = false;
      } else {
         isDowntrend = false;
      }
   };
   
   if (isUptrend) {
      return "UP_TREND";
   } else if (isDowntrend) {
      return "DOWN_TREND";
   } else {
      return "SIDE_WAY";
   }

}

bool CheckIfPositionClosed(ulong ticket, long type)
{
   if (type != TRADE_TRANSACTION_DEAL_ADD) return false;
   
   HistorySelectByPosition(ticket);
   double closedVolume = 0.0;
   for (int i = 1; i < HistoryDealsTotal(); i++)
      {
         closedVolume += HistoryDealGetDouble(HistoryDealGetTicket(i), DEAL_VOLUME);
         ulong deal_ticket = HistoryDealGetTicket(i);
         int reason = (int)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
         if (reason == DEAL_REASON_SL) {
            lastCloseReason = "SL";
         }
         if (reason == DEAL_REASON_TP) {
            lastCloseReason = "TP";
         }
      }
   return closedVolume == HistoryDealGetDouble(HistoryDealGetTicket(0), DEAL_VOLUME);
}



//+------------------------------------------------------------------+
//| Open Long position                                               |
//+------------------------------------------------------------------+

void LongPositionOpen()
  {
   if(!PositionSelect(_Symbol))
     {
      MqlTradeRequest mrequest;                             // Will be used for trade requests
      MqlTradeResult mresult;                               // Will be used for results of trade requests
      
      ZeroMemory(mrequest);
      ZeroMemory(mresult);
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      lastOrderAsk = ask;    // Ask price
      lastOrderBid = bid;    // Bid price
      int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT); //  Calculate pip size
      double stopLoss = bid - 300 * pipSize;
      double takeProfit = bid + 100 * pipSize;
   
      mrequest.action = TRADE_ACTION_DEAL;               // Immediate order execution
      mrequest.price = NormalizeDouble(lastOrderAsk,digits);      // Lastest Ask price
      mrequest.sl = NormalizeDouble(stopLoss,digits); ;                                   // Stop Loss
      mrequest.tp = NormalizeDouble(takeProfit,digits); ;                                   // Take Profit
      mrequest.symbol = _Symbol;                     // Symbol
      mrequest.volume = 0.01;                             // Number of lots to trade
                               // Magic Number
      mrequest.type = ORDER_TYPE_BUY;                    // Buy Order
      mrequest.type_filling = ORDER_FILLING_FOK;         // Order execution type
      mrequest.deviation=5;                              // Deviation from current price
      
      bool success = OrderSend(mrequest,mresult);                       // Send order
      isOpenBuy = true;
      isOpenSell = false;
      if (success) {
         lastOrderTicket = mresult.order;
         
      }
      
     }
  }
//+------------------------------------------------------------------+
//| Open Short position                                              |
//+------------------------------------------------------------------+
void ShortPositionOpen()
  {
   if(!PositionSelect(_Symbol))
     {
      MqlTradeRequest mrequest;                             // Will be used for trade requests
      MqlTradeResult mresult;                               // Will be used for results of trade requests
      
      ZeroMemory(mrequest);
      ZeroMemory(mresult);
      
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      lastOrderAsk = ask;    // Ask price
      lastOrderBid = bid;    // Bid price    // Bid price
      int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT); //  Calculate pip size
      double stopLoss = ask + 300 * pipSize;
      double takeProfit = ask - 100 * pipSize;
      mrequest.action = TRADE_ACTION_DEAL;               // Immediate order execution
      mrequest.price = NormalizeDouble(lastOrderBid,digits);     // Lastest Bid price
      mrequest.sl = NormalizeDouble(stopLoss,digits);                                    // Stop Loss
      mrequest.tp = NormalizeDouble(takeProfit,digits);                                    // Take Profit
      mrequest.symbol = _Symbol;                         // Symbol
      mrequest.volume = 0.01;                             // Number of lots to trade
      mrequest.magic = magicNumber1;                                // Magic Number
      mrequest.type= ORDER_TYPE_SELL;                    // Sell order
      mrequest.type_filling = ORDER_FILLING_FOK;         // Order execution type
      mrequest.deviation=5;                              // Deviation from current price
      
      bool success = OrderSend(mrequest,mresult);                       // Send order
      isOpenSell = true;
         isOpenBuy = false;
      if (success) {
         lastOrderTicket = mresult.order;
      }
     }
  }
  
  void LongDCAPositionOpen()
  {
   MqlTradeRequest mrequest;                             // Will be used for trade requests
   MqlTradeResult mresult;                               // Will be used for results of trade requests
   
   
   ZeroMemory(mrequest);
   ZeroMemory(mresult);
   
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);    // Ask price
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);    // Bid price
   int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT); //  Calculate pip size
   double stopLoss = bid - 150 * pipSize;
   double takeProfit = bid + 100 * pipSize;

  
     
      
      // DCA Position
      mrequest.action = TRADE_ACTION_DEAL;               // Immediate order execution
      mrequest.price = NormalizeDouble(ask,digits);      // Lastest Ask price
      mrequest.sl = NormalizeDouble(stopLoss,digits);                                   // Stop Loss
      mrequest.tp = NormalizeDouble(takeProfit,digits);                                  // Take Profit
      mrequest.symbol = _Symbol;                     // Symbol
      mrequest.volume = 0.02;                             // Number of lots to trade
                                     // Magic Number
      mrequest.type = ORDER_TYPE_BUY;                    // Buy Order
      mrequest.type_filling = ORDER_FILLING_FOK;         // Order execution type
      mrequest.deviation=5;                              // Deviation from current price
      OrderSend(mrequest,mresult);                       // Send order
      isOpenBuyDCA = true;
      
      trade.PositionModify(PositionGetTicket(0),NormalizeDouble(stopLoss,digits),NormalizeDouble(takeProfit,digits)); 
  }
  
 void ShortDCAPositionOpen()
  {
   MqlTradeRequest mrequest;                             // Will be used for trade requests
   MqlTradeResult mresult;                               // Will be used for results of trade requests
   
   ZeroMemory(mrequest);
   ZeroMemory(mresult);
   
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);    // Ask price
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);    // Bid price
   int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT); //  Calculate pip size
   double stopLoss = ask + 150 * pipSize;
   double takeProfit = ask - 100 * pipSize;

      
      // Order new position
      mrequest.action = TRADE_ACTION_DEAL;               // Immediate order execution
      mrequest.price = NormalizeDouble(bid,digits);      // Lastest Ask price
      mrequest.sl = NormalizeDouble(stopLoss,digits);                                   // Stop Loss
      mrequest.tp = NormalizeDouble(takeProfit,digits);                                    // Take Profit
      mrequest.symbol = _Symbol;                     // Symbol
      mrequest.volume = 0.02;                             // Number of lots to trade
                                      // Magic Number
      mrequest.type = ORDER_TYPE_SELL;                    // Buy Order
      mrequest.type_filling = ORDER_FILLING_FOK;         // Order execution type
      mrequest.deviation=5;                              // Deviation from current price
      OrderSend(mrequest,mresult);   
      isOpenSellDCA = true;   
      
      trade.PositionModify(PositionGetTicket(0),NormalizeDouble(stopLoss,digits),NormalizeDouble(takeProfit,digits));            
  
  }
//+------------------------------------------------------------------+
