//+------------------------------------------------------------------+
//|                                                trialEA.mq5 |
//|                                  Copyright 2025, App Cross  Ltd. |
//|                                       https://www.keterdidit.com |
//|                     telegram link:https://t.me/+GzUWeTLodfpjZWU0 |
// 

//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AppCross. Ltd."
#property link      "https://www.keterdidit.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Expert Setup                                                     |
//+------------------------------------------------------------------+
//Libraries and Setup
#include  <Trade/Trade.mqh> //Include MQL trade object functions

CTrade    *Trade;           //Declaire Trade as pointer to CTrade class
input int MagicNumber = 100001;  //Unique Identifier
ulong TicketNumber[]; //


//Multi-Symbol EA Variables
enum   MULTISYMBOL {Current, All}; 
input  MULTISYMBOL InputMultiSymbol = Current;
string AllTradableSymbols   = "XAUUSD";
int    NumberOfTradeableSymbols;
string SymbolArray[];

//Expert Core Arrays
string          SymbolMetrics[];
int             TicksProcessed[];
static datetime TimeLastTickProcessed[];

//Expert Variables
string ExpertComments = "";
int    TicksReceived  =  0;

 // Global variables for lot size calculation
input bool UseFixedLotSize = false; // Fixed Lot Size?
input double FixedLotSize = 0.1; // Lot Size
input double riskPercentage = 0.02; // Risk Percentage

// RSI Variables
string  IndicatorSignal1;
int       RsiHandle[];
input int RsiPeriod = 14; // RSI Period

// EMA Variables
string    IndicatorSignal2;
int       EmaHandle[];
input int EmaPeriod = 7; // EMA Period

// SMA Variables
string    IndicatorSignal3;
int       SmaHandle[];
input int SmaPeriod = 1; // SMA1 Period

// ATR Variables
string    IndicatorSignal4;
int       AtrHandle[];
input int AtrPeriod = 14; //ATR Period

// Bollinger Bands Variables
string    IndicatorSignal5;
int BollingerHandle[];        // Handles for Bollinger Bands indicators
input int BollingerPeriod = 20;     // Default period for Bollinger Bands
input double BollingerDeviation = 2.0;  // Default deviation for Bollinger Bands


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //Declare magic number for all trades
   Trade = new CTrade();
   Trade.SetExpertMagicNumber(MagicNumber);  
   
   //Set up multi-symbol EA Tradable Symbols
   if(InputMultiSymbol == Current)
   {
      NumberOfTradeableSymbols = 1;
      ArrayResize(SymbolArray,NumberOfTradeableSymbols);
      SymbolArray[0] = Symbol();
      Print("EA will process ", NumberOfTradeableSymbols, " Symbol: ", SymbolArray[0]);
   } 
   else
   {
      NumberOfTradeableSymbols = StringSplit(AllTradableSymbols, '|', SymbolArray);
      ArrayResize(SymbolArray,NumberOfTradeableSymbols);
      Print("EA will process ", NumberOfTradeableSymbols, " Symbols: ", AllTradableSymbols);
   }
   
   //Resize core arrays for Multi-Symbol EA
   ResizeCoreArrays();   
   
   //Resize indicator arrays for Multi-Symbol EA
   ResizeIndicatorArrays();
   
   //Set Up Multi-Symbol Handles for Indicators
   if(!RsiHandleMultiSymbol() || !EmaHandleMultiSymbol() || !SmaHandleMultiSymbol() || !AtrHandleMultiSymbol ()|| !BollingerHandleMultiSymbol())
       return(INIT_FAILED);
    // Add this call to debug symbol properties
    
   // Attach indicators to the chart
   // Attach indicators to the chart, ensuring subwindow index is included
   ChartIndicatorAdd(ChartID(), 1, RsiHandle[1]);         // RSI added to main chart
   ChartIndicatorAdd(ChartID(), 2, RsiHandle[0]);         // RSI added to main chart
   ChartIndicatorAdd(ChartID(), 0, EmaHandle[0]);         // EMA added to main chart
   ChartIndicatorAdd(ChartID(), 0, SmaHandle[0]);         // SMA added to main chart
   ChartIndicatorAdd(ChartID(), 1, AtrHandle[0]);        // ATR added to subwindow 1
   ChartIndicatorAdd(ChartID(), 0, BollingerHandle[0]);  // Bollinger Bands added to subwindow 1
   
    Print("Indicators successfully added to the chart.");

   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //Release Indicator Arrays
   ReleaseIndicatorArrays();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   ExpertComments = "";
   TicksReceived++;
 

   for (int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      string CurrentSymbol = SymbolArray[SymbolLoop];
   //Check for new candle based of opening time of bar
      bool IsNewCandle = false;   
      if(TimeLastTickProcessed[SymbolLoop] != iTime(CurrentSymbol,Period(),0))
      {
         IsNewCandle   = true;
         TimeLastTickProcessed[SymbolLoop]  = iTime(CurrentSymbol,Period(),0);      
      } 
      //Process strategy only if is new candle
      if(IsNewCandle == true)
      {
         TimeLastTickProcessed[SymbolLoop] = iTime(CurrentSymbol, Period(), 0);

         IndicatorSignal1 = GetRsiSignal(SymbolLoop);
         
         IndicatorSignal2 = GetEmaOpenSignal(SymbolLoop);
         
         IndicatorSignal3 = GetSmaOpenSignal(SymbolLoop);
         
         IndicatorSignal4 = GetAtrValue(SymbolLoop);
         
         IndicatorSignal5 = GetBollingerSignal(SymbolLoop);
         

         Print(CurrentSymbol, ": RSI Signal=", IndicatorSignal1, ", EMA Signal=", IndicatorSignal2, ", SMA Signal=", IndicatorSignal3, ", ATR Signal=", IndicatorSignal4, ", BollingerBand Signal=", IndicatorSignal5);

  

         bool hasBuyPosition = false, hasSellPosition = false;
         for (int i = 0; i < PositionsTotal(); i++)
         {
            if (PositionGetSymbol(i) == CurrentSymbol)
            {
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) hasBuyPosition = true;
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) hasSellPosition = true;
            }
         }

         ENUM_ORDER_TYPE OrderType;

         // Dynamic Trade Decisions Based on Signals
         if (IndicatorSignal5 == "Short" && IndicatorSignal2 == "Long")
         {
         if (!hasBuyPosition)
            {
               Print("Opening BUY trade for ", CurrentSymbol);
               OrderType = ORDER_TYPE_BUY; 
               ProcessTradeOpen(CurrentSymbol, OrderType,SymbolLoop); //Open positions and store ticket
            
            }
            else
            {
               Print("BUY position already open for ", CurrentSymbol);
            }
         }
         else if (IndicatorSignal5 == "Long" && IndicatorSignal2 == "Short")
         {
            if (!hasSellPosition)
            {
               Print("Opening SELL trade for ", CurrentSymbol);
               OrderType = ORDER_TYPE_SELL;
               ProcessTradeOpen(CurrentSymbol, OrderType,SymbolLoop); //Open positions and store ticket
            
            }
            else
            {
               Print("SELL position already open for ", CurrentSymbol);
            }
         }
   // Update Symbol Metrics with trade decisions
         SymbolMetrics[SymbolLoop] = CurrentSymbol +
                                     " | Ticks Processed: " + IntegerToString(TicksProcessed[SymbolLoop]) +
                                     " | Last Candle: " + TimeToString(TimeLastTickProcessed[SymbolLoop]) +
                                     " | Trade Decision: " + ((IndicatorSignal1 == "Long" && IndicatorSignal2 == "Long" && IndicatorSignal3 == "Long") ? "BUY" :
                                                               (IndicatorSignal1 == "Short" && IndicatorSignal2 == "Short" && IndicatorSignal3 == "Short") ? "SELL" : "HOLD");

         // Update expert comments for each symbol
         ExpertComments = ExpertComments + SymbolMetrics[SymbolLoop] + "\n\r";
      }
   }

   // Comment expert behavior
   Comment("\n\rExpert: ", MagicNumber, "\n\r",
           "Symbols Traded:\n\r",
           ExpertComments);
            // Update trailing stop loss and take profit
   UpdateTrailingStops();
}

//+------------------------------------------------------------------+
//| Expert custom function                                           |
//+------------------------------------------------------------------+
//Resize Core Arrays for multi-symbol EA
void ResizeCoreArrays()
{
   ArrayResize(SymbolMetrics,         NumberOfTradeableSymbols);
   ArrayResize(TicksProcessed,        NumberOfTradeableSymbols); 
   ArrayResize(TimeLastTickProcessed, NumberOfTradeableSymbols);
   
   
}

//Resize Indicator for multi-symbol EA
void ResizeIndicatorArrays()
{
   //Indicator Handle Arrays
   ArrayResize(BollingerHandle, NumberOfTradeableSymbols);
   ArrayResize(AtrHandle, NumberOfTradeableSymbols);
   ArrayResize(RsiHandle, NumberOfTradeableSymbols);
   ArrayResize(EmaHandle,  NumberOfTradeableSymbols);
   ArrayResize(SmaHandle,  NumberOfTradeableSymbols);

   
}

//Release indicator handles from Metatrader cache for multi-symbol EA
void ReleaseIndicatorArrays()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      IndicatorRelease(BollingerHandle[SymbolLoop]);
      IndicatorRelease(AtrHandle[SymbolLoop]);
      IndicatorRelease(RsiHandle[SymbolLoop]);
      IndicatorRelease(EmaHandle[SymbolLoop]);
      IndicatorRelease(SmaHandle[SymbolLoop]);

   }
   Print("Handle released for all symbols");   
}

//+------------------------------------------------------------------+
//| Set up RSI Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool RsiHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      RsiHandle[SymbolLoop] = iRSI(SymbolArray[SymbolLoop], Period(), RsiPeriod, PRICE_CLOSE); 
      if(RsiHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for RSI indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for RSI for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get RSI Value                                                    |
//+------------------------------------------------------------------+
double GetRsiValue(int SymbolLoop)
{
     const int StartCandle     = 0;
   const int RequiredCandles = 2; //How many candles are required to be stored in Expert 

   //Indicator Variables and Buffers
   const int IndexRSI        = 0; //RSI Value
   double BufferRSI[];
    bool FillRsi = CopyBuffer(RsiHandle[SymbolLoop],IndexRSI,StartCandle,RequiredCandles, BufferRSI);
    if(FillRsi==false)return("FILL_ERROR");
    
     //Find ATR Value for Candle '1' Only
   double CurrentRsi   = NormalizeDouble(BufferRSI[1],5);
   
   return (CurrentRsi);
}

//+------------------------------------------------------------------+
//| Get RSI Signal                                                   |
//+------------------------------------------------------------------+
string GetRsiSignal(int SymbolLoop)
{
      double CurrentRsi = GetRsiValue(SymbolLoop);
    
       if(CurrentRsi < 25)
      return("Long");
   else if(CurrentRsi > 75)
      return("Short");
   else
      return("No Trade");
}


//+------------------------------------------------------------------+
//| Set up Ema Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool EmaHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      EmaHandle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],Period(),EmaPeriod,0,MODE_EMA,PRICE_CLOSE); 
      if(EmaHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for Ema indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Ema for all Symbols successfully created");
   return true;
}
//+------------------------------------------------------------------+
//| Get EMA Signals based off EMA line and price close       |
//+------------------------------------------------------------------+
string GetEmaOpenSignal(int SymbolLoop)
{
   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = 2; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int IndexEma        = 0; //Ema Line
   double    BufferEma[];         //Capture 2 candles for EMA [0,1]

   //Populate buffers for EMA line
   bool FillEma   = CopyBuffer(EmaHandle[SymbolLoop],IndexEma,StartCandle,RequiredCandles,BufferEma);
   if(FillEma==false)return("FILL_ERROR");

   //Find required EMA signal lines
   double CurrentEma = NormalizeDouble(BufferEma[1],10);
   
   //Get last confirmed candle price. NOTE:Use last value as this is when the candle is confirmed. Ask/bid gives some errors.
   double CurrentClose = NormalizeDouble(iClose(SymbolArray[SymbolLoop],Period(),0), 10);

   //Submit Ema Long and Short Trades
   if(CurrentClose > CurrentEma)
      return("Long");
   else if (CurrentClose < CurrentEma)
      return("Short");
   else
      return("No Trade");
}

//+------------------------------------------------------------------+
//| Set up Sma Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool SmaHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      SmaHandle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],Period(),SmaPeriod,0,MODE_SMA,PRICE_CLOSE); 
      if(SmaHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for Ema indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Sma for all Symbols successfully created");
   return true;
}
//+------------------------------------------------------------------+
//| Get SMA Signals based off SMA line and price close     |
//+------------------------------------------------------------------+
string GetSmaOpenSignal(int SymbolLoop)
{
   const int StartCandle     = 0;
   const int RequiredCandles = 2; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int IndexSma        = 0; //Ema Line
   double    BufferSma[];         //Capture 2 candles for EMA [0,1]

   //Populate buffers for EMA line
   bool FillSma = CopyBuffer(SmaHandle[SymbolLoop], IndexSma, StartCandle, RequiredCandles, BufferSma);
   if(FillSma==false)return("FILL_ERROR");

   //Find required EMA signal lines
   double CurrentSma = NormalizeDouble(BufferSma[1], 10);
   
   //Get last confirmed candle price. NOTE:Use last value as this is when the candle is confirmed. Ask/bid gives some errors.
   double CurrentClose = NormalizeDouble(iClose(SymbolArray[SymbolLoop],Period(),0), 10);

   //Submit Sma Long and Short Trades
   if(CurrentClose > CurrentSma)
      return("Long");
   else if (CurrentClose < CurrentSma)
      return("Short");
   else
      return("No Trade");

}
//+------------------------------------------------------------------+
//| Set up ATR Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool AtrHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      AtrHandle[SymbolLoop] = iATR(SymbolArray[SymbolLoop], Period(), AtrPeriod); 
      if(AtrHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for ATR indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for ATR for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                    |
//+------------------------------------------------------------------+
double GetAtrValue(int SymbolLoop)
{
      const int StartCandle     = 0;
   const int RequiredCandles = 2; //How many candles are required to be stored in Expert 

   //Indicator Variables and Buffers
   const int IndexAtr        = 0; //ATR Value
   double    BufferAtr[];         //[prior,current confirmed,not confirmed] 

   //Populate buffers for ATR Value; check errors
   bool FillAtr = CopyBuffer(AtrHandle[SymbolLoop],IndexAtr,StartCandle,RequiredCandles,BufferAtr); //Copy buffer uses oldest as 0 (reversed)
   if(FillAtr==false)return(0);

   //Find ATR Value for Candle '1' Only
   double CurrentAtr   = NormalizeDouble(BufferAtr[1],5);

   //Return ATR Value
   return(CurrentAtr);
}
//+------------------------------------------------------------------+
//| Set up Bollinger Bands Handle for Multi-Symbol EA                |
//+------------------------------------------------------------------+
bool BollingerHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      BollingerHandle[SymbolLoop] = iBands(SymbolArray[SymbolLoop], Period(), BollingerPeriod, BollingerDeviation, 0, PRICE_CLOSE); 
      if(BollingerHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for Bollinger Bands indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Bollinger Bands for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands Signal                                       |
//+------------------------------------------------------------------+
string GetBollingerSignal(int SymbolLoop)
{
   double BufferUpperBand[];
   double BufferLowerBand[];
   double currentPrice = iClose(SymbolArray[SymbolLoop], Period(), 0);

   if(CopyBuffer(BollingerHandle[SymbolLoop], 0, 0, 1, BufferUpperBand) <= 0 || CopyBuffer(BollingerHandle[SymbolLoop], 1, 0, 1, BufferLowerBand) <= 0)
   {
      Print("Failed to get Bollinger Bands value for ", SymbolArray[SymbolLoop]);
      return "No Trade";
   }

   if(currentPrice <= BufferLowerBand[0])
      return ("Long");
   else if(currentPrice >= BufferUpperBand[0])
      return ("Short");
   else
      return ("No Trade");
}
double CalculateLotSize()
{
   double lotSize;
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   if (UseFixedLotSize)
   {
      lotSize = FixedLotSize;
   }
   else
   {
      // Adjusted calculation using contract size
      double contractSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);
      lotSize = (accountBalance * riskPercentage) / contractSize;
   }
   
   // Ensure lot size is within broker's limits
   double minLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   // Normalize lot size
   lotSize = MathMax(minLotSize, MathMin(maxLotSize, NormalizeDouble(lotSize, SymbolInfoInteger(Symbol(), SYMBOL_DIGITS))));
   lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

   Print("Final Lot Size: ", lotSize); // Debugging Output
   return lotSize;
}

//+------------------------------------------------------------------+
//| Process trades                                                   |
//+------------------------------------------------------------------+
ulong ProcessTradeOpen(string CurrentSymbol, ENUM_ORDER_TYPE OrderType, int SymbolLoop)
{
   //Calculate Risk Amount for user
   double minStopLevel = SymbolInfoInteger(CurrentSymbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

  //Set symbol string and variables 
   int    SymbolDigits    = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error
   double Price           = 0.0;
   double StopLossPrice   = 0.0;
   double StopLossSize    = 1.0;
   double TakeProfitPrice = 0.0;
   double TakeProfitSize  = 2.0;

   //Open buy or sell orders
   if(OrderType == ORDER_TYPE_BUY)
   {
      Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK), SymbolDigits);
      StopLossPrice   = NormalizeDouble(Price - StopLossSize, SymbolDigits);
      TakeProfitPrice = NormalizeDouble(Price + TakeProfitSize, SymbolDigits);
   } 
   else if(OrderType == ORDER_TYPE_SELL)
   {
       Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_BID), SymbolDigits);
       StopLossPrice   = NormalizeDouble(Price + StopLossSize, SymbolDigits);
       TakeProfitPrice = NormalizeDouble(Price - TakeProfitSize, SymbolDigits);
   }
   
   //Get lot size
    double LotSize = CalculateLotSize();
   
   //Close any current positions and open new position
   Trade.PositionClose(CurrentSymbol);  
   Trade.PositionOpen(CurrentSymbol, OrderType, LotSize, Price, StopLossPrice, TakeProfitPrice, __FILE__);


   //Print successful
   Print("Trade Processed For ", CurrentSymbol," OrderType ",OrderType, " Lot Size ", LotSize);
   Print("Price: ", Price, " StopLossPrice: ", StopLossPrice, " TakeProfitPrice: ", TakeProfitPrice, " Min Stop Level: ", minStopLevel);

   Print("Calculated Lot Size: ", LotSize);

   return(true);
}


//+------------------------------------------------------------------+
//| Update trailing stop loss and take profit                        |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double newStopLoss, newTakeProfit;

   Print(" Ticket: ", ticket, " Symbol: ", symbol, "Price: ", price,  " StopLossPrice: ", stopLoss, " TakeProfitPrice:", takeProfit);
      // Ensure the symbol is in the tradable symbols
      bool isTradableSymbol = false;
      int SymbolLoop = -1;
      for(int j = 0; j < NumberOfTradeableSymbols; j++)
      {
         if(SymbolArray[j] == symbol)
         {
            isTradableSymbol = true;
            SymbolLoop = j;
            break;
         }
      }

      if(isTradableSymbol)
      {
         double atr = GetAtrValue(SymbolLoop);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            newStopLoss = price - 1.5 * atr;
            newTakeProfit = price + 1.5 * atr;
            if(newStopLoss > stopLoss)
            {
               Trade.PositionModify(ticket, newStopLoss, takeProfit);
               NotifyUser("Trailing Stop Loss updated for " + symbol + " to " + DoubleToString(newStopLoss, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
            if(newTakeProfit > takeProfit)
            {
               Trade.PositionModify(ticket, stopLoss, newTakeProfit);
               NotifyUser("Trailing Take Profit updated for " + symbol + " to " + DoubleToString(newTakeProfit, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            newStopLoss = price + 1.5 *  atr;
            newTakeProfit = price - 1.5 * atr;
            if(newStopLoss < stopLoss)
            {
               Trade.PositionModify(ticket, newStopLoss, takeProfit);
               NotifyUser("Trailing Stop Loss updated for " + symbol + " to " + DoubleToString(newStopLoss, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
            if(newTakeProfit < takeProfit)
            {
               Trade.PositionModify(ticket, stopLoss, newTakeProfit);
               NotifyUser("Trailing Take Profit updated for " + symbol + " to " + DoubleToString(newTakeProfit, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Notify user                                                      |
//+------------------------------------------------------------------+
void NotifyUser(string message)
{
   Print(message);
   // You can also use other notification methods like sending an email or push notification
}

//+------------------------------------------------------------------+
