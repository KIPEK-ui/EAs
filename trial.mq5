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
string AllTradableSymbols   = "XAUUSD|XAGUSD";
int    NumberOfTradeableSymbols;
string SymbolArray[];

//Expert Core Arrays
string          SymbolMetrics[];
int             TicksProcessed[];
static datetime TimeLastTickProcessed[];

//Expert Variables
string ExpertComments = "";
int    TicksReceived  =  0;

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
      ArrayResize(TicketNumber, NumberOfTradeableSymbols);
      SymbolArray[0] = Symbol();
      Print("EA will process ", NumberOfTradeableSymbols, " Symbol: ", SymbolArray[0]);
   } 
   else
   {
      NumberOfTradeableSymbols = StringSplit(AllTradableSymbols, '|', SymbolArray);
      ArrayResize(SymbolArray,NumberOfTradeableSymbols);
      ArrayResize(TicketNumber, NumberOfTradeableSymbols);
      Print("EA will process ", NumberOfTradeableSymbols, " Symbols: ", AllTradableSymbols);
   }
   
   //Resize core arrays for Multi-Symbol EA
   ResizeCoreArrays();   
   
   //Resize indicator arrays for Multi-Symbol EA
   ResizeIndicatorArrays();
   
   //Set Up Multi-Symbol Handles for Indicators
   if(!RsiHandleMultiSymbol() || !EmaHandleMultiSymbol() || !SmaHandleMultiSymbol())
       return(INIT_FAILED);
    // Add this call to debug symbol properties
   DebugSymbolProperties();
   
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
      bool IsNewCandle = TimeLastTickProcessed[SymbolLoop] != iTime(CurrentSymbol, Period(), 0);

      if (IsNewCandle)
      {
         TimeLastTickProcessed[SymbolLoop] = iTime(CurrentSymbol, Period(), 0);

         IndicatorSignal1 = GetRsiOpenSignal(SymbolLoop);
         
         IndicatorSignal2 = GetEmaOpenSignal(SymbolLoop);
         
         IndicatorSignal3 = GetSmaOpenSignal(SymbolLoop);
         

         Print(CurrentSymbol, ": RSI Signal=", IndicatorSignal1, ", EMA Signal=", IndicatorSignal2, ", SMA Signal=", IndicatorSignal3);

    

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
         if (IndicatorSignal1 == "Short" && IndicatorSignal2 == "Long")
         {
         if (!hasBuyPosition)
            {
               Print("Opening BUY trade for ", CurrentSymbol);
               OrderType = ORDER_TYPE_BUY; 
               TicketNumber[SymbolLoop]  = ProcessTradeOpen(CurrentSymbol, OrderType,SymbolLoop); //Open positions and store ticket
            
            }
            else
            {
               Print("BUY position already open for ", CurrentSymbol);
            }
         }
         else if (IndicatorSignal1 == "Long" && IndicatorSignal2 == "Short")
         {
            if (!hasSellPosition)
            {
               Print("Opening SELL trade for ", CurrentSymbol);
               OrderType = ORDER_TYPE_SELL;
               TicketNumber[SymbolLoop]  = ProcessTradeOpen(CurrentSymbol, OrderType,SymbolLoop); //Open positions and store ticket
            
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
   ArrayResize(RsiHandle, NumberOfTradeableSymbols);
   ArrayResize(EmaHandle,  NumberOfTradeableSymbols);
   ArrayResize(SmaHandle,  NumberOfTradeableSymbols);

   
}

//Release indicator handles from Metatrader cache for multi-symbol EA
void ReleaseIndicatorArrays()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
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
//| Get RSI Signal                                                    |
//+------------------------------------------------------------------+
string GetRsiOpenSignal(int SymbolLoop)
{
   const int BufferNo = 0;
   const int StartCandle     = 0;
   const int RequiredCandles = 1; 
   double BufferRSI[];
   
   
   bool FillRsi = CopyBuffer(RsiHandle[SymbolLoop],BufferNo,StartCandle, RequiredCandles, BufferRSI);
    if(FillRsi==false)return("FILL_ERROR");
    
    double    CurrentRsi   = NormalizeDouble(BufferRSI[1],10);
    
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
//| Process trades                                                   |
//+------------------------------------------------------------------+
ulong ProcessTradeOpen(string CurrentSymbol, ENUM_ORDER_TYPE OrderType, int SymbolLoop)
{
   //Calculate Risk Amount for user
  //Set symbol string and variables 
   int    SymbolDigits    = (int) SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS); //note - typecast required to remove error
   double Price           = 0.0;
   double StopLossPrice   = 0.0;
   double StopLossSize    = 0.1;
   double TakeProfitPrice = 0.0;
   double TakeProfitSize  = 0.2;

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
   double LotSize = 0.1;
   
   //Close any current positions and open new position
   Trade.PositionClose(CurrentSymbol);
   Trade.SetExpertMagicNumber(MagicNumber);  
   Trade.PositionOpen(CurrentSymbol,OrderType,LotSize,Price,StopLossPrice,TakeProfitPrice,__FILE__);
   //Print successful
   Print("Trade Processed For ", CurrentSymbol," OrderType ",OrderType, " Lot Size ", LotSize);
   
   return(true);
}
//+------------------------------------------------------------------+
//| Debug Symbol Properties                                          |
//+------------------------------------------------------------------+
void DebugSymbolProperties()
{
   for (int i = 0; i < NumberOfTradeableSymbols; i++)
   {
      string CurrentSymbol = SymbolArray[i];

      // Retrieve symbol properties
      double pointValue = SymbolInfoDouble(CurrentSymbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS);
      double minStopLevel = SymbolInfoInteger(CurrentSymbol, SYMBOL_TRADE_STOPS_LEVEL) * pointValue;

      // Print the properties to the log
      Print("Symbol: ", CurrentSymbol, 
            " | Point Value: ", DoubleToString(pointValue, digits), 
            " | Digits: ", digits, 
            " | Minimum Stop Level: ", DoubleToString(minStopLevel, digits));
   }
}


