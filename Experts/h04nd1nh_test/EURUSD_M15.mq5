//+------------------------------------------------------------------+
//|                                                   EURUSD_M15.mq5 |
//|                                  Copyright 2024, h04nd1nh        |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

       
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
      
      bool buyFirstOpenCondition = (checkTrend() == "UP_TREND" && bid <= BBLow[0]);
      bool sellFirstOpenCondition = (checkTrend() == "DOWN_TREND" && ask >= BBUp[0]);
      double lastOrderAskTemp = lastOrderAsk;
      double lastOrderBidTemp = lastOrderBid;
      bool buySecondOpenCondition = (isOpenBuy && !isOpenBuyDCA && ask <= (lastOrderAskTemp - 150*pipSize));
      bool sellSecondOpenCondition = (isOpenSell && !isOpenSellDCA && bid >= (lastOrderBidTemp + 150*pipSize));
      
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
  }
//+------------------------------------------------------------------+

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{ 
 if(trans.symbol!=_Symbol) return;  
 if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
 if(!PositionSelect(_Symbol)) {
   isOpenBuy = false;
   isOpenSell = false;
   isOpenSellDCA = false;
   isOpenBuyDCA = false;
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


//+------------------------------------------------------------------+
//| Open Long position                                               |
//+------------------------------------------------------------------+

void LongPositionOpen()
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
   double stopLoss = ask - 300 * pipSize;
   double takeProfit = bid + 100 * pipSize;

   if(!PositionSelect(_Symbol))
     {
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
      
      if (success) {
         lastOrderTicket = mresult.order;
         isOpenBuy = true;
      }
     }
  }
//+------------------------------------------------------------------+
//| Open Short position                                              |
//+------------------------------------------------------------------+
void ShortPositionOpen()
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
   double takeProfit = bid - 100 * pipSize;

   if(!PositionSelect(_Symbol))
     {
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
      
      if (success) {
         lastOrderTicket = mresult.order;
         isOpenSell = true;
      }
     }
  }
  
  void LongDCAPositionOpen()
  {
  Print("Long DCA Open");
   MqlTradeRequest mrequest;                             // Will be used for trade requests
   MqlTradeResult mresult;                               // Will be used for results of trade requests
   
   
   ZeroMemory(mrequest);
   ZeroMemory(mresult);
   
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);    // Ask price
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);    // Bid price
   int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT); //  Calculate pip size
   double stopLoss = ask - 150 * pipSize;
   double takeProfit = ask + 150 * pipSize;

  
     
      
      // DCA Position
      mrequest.action = TRADE_ACTION_DEAL;               // Immediate order execution
      mrequest.price = NormalizeDouble(ask,digits);      // Lastest Ask price
      mrequest.sl = NormalizeDouble(stopLoss,digits); ;                                   // Stop Loss
      mrequest.tp = NormalizeDouble(takeProfit,digits); ;                                   // Take Profit
      mrequest.symbol = _Symbol;                     // Symbol
      mrequest.volume = 0.02;                             // Number of lots to trade
                                     // Magic Number
      mrequest.type = ORDER_TYPE_BUY;                    // Buy Order
      mrequest.type_filling = ORDER_FILLING_FOK;         // Order execution type
      mrequest.deviation=5;                              // Deviation from current price
      OrderSend(mrequest,mresult);                       // Send order
      isOpenBuyDCA = true;
     
  }
  
 void ShortDCAPositionOpen()
  {
   Print("Short DCA Open");
   MqlTradeRequest mrequest;                             // Will be used for trade requests
   MqlTradeResult mresult;                               // Will be used for results of trade requests
   
   ZeroMemory(mrequest);
   ZeroMemory(mresult);
   
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);    // Ask price
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);    // Bid price
   int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT); //  Calculate pip size
   double stopLoss = bid + 150 * pipSize;
   double takeProfit = bid - 150 * pipSize;

      
      // Order new position
      mrequest.action = TRADE_ACTION_DEAL;               // Immediate order execution
      mrequest.price = NormalizeDouble(bid,digits);      // Lastest Ask price
      mrequest.sl = NormalizeDouble(stopLoss,digits); ;                                   // Stop Loss
      mrequest.tp = NormalizeDouble(takeProfit,digits); ;                                   // Take Profit
      mrequest.symbol = _Symbol;                     // Symbol
      mrequest.volume = 0.02;                             // Number of lots to trade
                                      // Magic Number
      mrequest.type = ORDER_TYPE_SELL;                    // Buy Order
      mrequest.type_filling = ORDER_FILLING_FOK;         // Order execution type
      mrequest.deviation=5;                              // Deviation from current price
      OrderSend(mrequest,mresult);   
      isOpenSellDCA = true;                    // Send order
  
  }
//+------------------------------------------------------------------+