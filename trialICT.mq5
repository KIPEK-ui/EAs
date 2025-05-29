//+------------------------------------------------------------------+
//|                                                trialEA.mq5 |
//|                                  Copyright 2025, App Cross  Ltd. |
//|                                       https://www.keterdidit.com |
//|                     telegram link:https://t.me/+GzUWeTLodfpjZWU0 |
//

//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AppCross. Ltd."
#property link "https://www.keterdidit.com"
#property version "1.00"

//+------------------------------------------------------------------+
//| Expert Setup                                                     |
//+------------------------------------------------------------------+
// Libraries and Setup
#include <Trade/Trade.mqh> //Include MQL trade object functions

CTrade *Trade;                  // Declaire Trade as pointer to CTrade class
input int MagicNumber = 100001; // Unique Identifier
ulong TicketNumber[];           //

// Multi-Symbol EA Variables
enum MULTISYMBOL
{
    Current,
    All
};
input MULTISYMBOL InputMultiSymbol = Current;
string AllTradableSymbols = "XAUUSD";
int NumberOfTradeableSymbols;
string SymbolArray[];

// Expert Core Arrays
string SymbolMetrics[];
int TicksProcessed[];
static datetime TimeLastTickProcessed[];

// Expert Variables
string ExpertComments = "";
int TicksReceived = 0;

// Global variables for lot size calculation
input bool UseFixedLotSize = false; // Fixed Lot Size?
input double FixedLotSize = 0.1;    // Lot Size
input double riskPercentage = 0.02; // Risk Percentage

// Global variables for FVG
double FvgHigh, FvgLow;
bool IsBullishFVG = false;
bool IsBearishFVG = false;
datetime FvgTime;

// ATR Variables
string IndicatorSignal1;
int AtrHandle[];
input int AtrPeriod = 14; // ATR Period

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Declare magic number for all trades
    Trade = new CTrade();
    Trade.SetExpertMagicNumber(MagicNumber);

    // Set up multi-symbol EA Tradable Symbols
    if (InputMultiSymbol == Current)
    {
        NumberOfTradeableSymbols = 1;
        ArrayResize(SymbolArray, NumberOfTradeableSymbols);
        SymbolArray[0] = Symbol();
        Print("EA will process ", NumberOfTradeableSymbols, " Symbol: ", SymbolArray[0]);
    }
    else
    {
        NumberOfTradeableSymbols = StringSplit(AllTradableSymbols, '|', SymbolArray);
        ArrayResize(SymbolArray, NumberOfTradeableSymbols);
        Print("EA will process ", NumberOfTradeableSymbols, " Symbols: ", AllTradableSymbols);
    }

    // Resize core arrays for Multi-Symbol EA
    ResizeCoreArrays();

    // Resize indicator arrays for Multi-Symbol EA
    ResizeIndicatorArrays();

    // Set Up Multi-Symbol Handles for Indicators
    if (!AtrHandleMultiSymbol())
        return (INIT_FAILED);
    // Add this call to debug symbol properties

    // Attach indicators to the chart
    // Attach indicators to the chart, ensuring subwindow index is included

    Print("Indicators successfully added to the chart.");

    return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release Indicator Arrays

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
        // Check for new candle based of opening time of bar
        bool IsNewCandle = false;
        if (TimeLastTickProcessed[SymbolLoop] != iTime(CurrentSymbol, Period(), 0))
        {
            IsNewCandle = true;
            TimeLastTickProcessed[SymbolLoop] = iTime(CurrentSymbol, Period(), 0);
        }
        // Process strategy only if is new candle
        if (IsNewCandle == true)
        {
            TimeLastTickProcessed[SymbolLoop] = iTime(CurrentSymbol, Period(), 0);

            IndicatorSignal1 = GetAtrValue(SymbolLoop);

            Print(CurrentSymbol, ": ATR Signal=", IndicatorSignal1);

            bool hasBuyPosition = false, hasSellPosition = false;
            for (int i = 0; i < PositionsTotal(); i++)
            {
                if (PositionGetSymbol(i) == CurrentSymbol)
                {
                    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                        hasBuyPosition = true;
                    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                        hasSellPosition = true;
                }
            }
            if (IsFairValueGap(SymbolLoop))
            {
                ENUM_ORDER_TYPE OrderType;

                // Dynamic Trade Decisions Based on Signals
                if (IsBullishFVG && iClose(SymbolArray[SymbolLoop], Period(), 0) > FvgLow)

                {
                    if (!hasBuyPosition)
                    {
                        Print("Opening BUY trade for ", CurrentSymbol);
                        OrderType = ORDER_TYPE_BUY;
                        ProcessTradeOpen(CurrentSymbol, OrderType, SymbolLoop); // Open positions and store ticket
                    }
                    else
                    {
                        Print("BUY position already open for ", CurrentSymbol);
                    }
                }
                else if (IsBearishFVG && iClose(SymbolArray[SymbolLoop], Period(), 0) < FvgHigh)
                {
                    if (!hasSellPosition)
                    {
                        Print("Opening SELL trade for ", CurrentSymbol);
                        OrderType = ORDER_TYPE_SELL;
                        ProcessTradeOpen(CurrentSymbol, OrderType, SymbolLoop);
                    }
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
                                        " | Trade Decision: ";
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
// Resize Core Arrays for multi-symbol EA
void ResizeCoreArrays()
{
    ArrayResize(SymbolMetrics, NumberOfTradeableSymbols);
    ArrayResize(TicksProcessed, NumberOfTradeableSymbols);
    ArrayResize(TimeLastTickProcessed, NumberOfTradeableSymbols);
}

// Resize Indicator for multi-symbol EA
void ResizeIndicatorArrays()
{
    // Indicator Handle Arrays
    ArrayResize(AtrHandle, NumberOfTradeableSymbols);
}

// Release indicator handles from Metatrader cache for multi-symbol EA
void ReleaseIndicatorArrays()
{
    for (int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
    {
        IndicatorRelease(AtrHandle[SymbolLoop]);
    }
    Print("Handle released for all symbols");
}
bool IsFairValueGap(int SymbolLoop)
{
    double BufferHigh[], BufferLow[];

    if (CopyBuffer(iHigh(SymbolArray[SymbolLoop], Period(), 0), 0, 3, 3, BufferHigh) <= 0 ||
        CopyBuffer(iLow(SymbolArray[SymbolLoop], Period(), 0), 0, 3, 3, BufferLow) <= 0)
    {
        Print("Error fetching candle data for FVG.");
        return false;
    }

    if (BufferLow[2] > BufferHigh[0])
    {
        FvgHigh = BufferHigh[0];
        FvgLow = BufferLow[2];
        IsBullishFVG = true;
        IsBearishFVG = false;
        FvgTime = TimeCurrent();
        return true;
    }

    if (BufferHigh[2] < BufferLow[0])
    {
        FvgHigh = BufferHigh[2];
        FvgLow = BufferLow[0];
        IsBullishFVG = false;
        IsBearishFVG = true;
        FvgTime = TimeCurrent();
        return true;
    }

    return false;
}
void DrawFairValueGap(int SymbolLoop)
{
    double BufferHigh[], BufferLow[];

    if (CopyBuffer(iHigh(SymbolArray[SymbolLoop], Period(), 0), 0, 3, 3, BufferHigh) <= 0 ||
        CopyBuffer(iLow(SymbolArray[SymbolLoop], Period(), 0), 0, 3, 3, BufferLow) <= 0)
    {
        Print("Error fetching candle data for FVG.");
        return;
    }

    // Update global FVG variables
    IsBullishFVG = BufferLow[2] > BufferHigh[0];
    IsBearishFVG = BufferHigh[2] < BufferLow[0];

    if (IsBullishFVG || IsBearishFVG)
    {
        FvgHigh = IsBullishFVG ? BufferHigh[0] : BufferHigh[2];
        FvgLow = IsBullishFVG ? BufferLow[2] : BufferLow[0];
        FvgTime = TimeCurrent();

        string FvgObjectName = "FVG_" + SymbolArray[SymbolLoop] + "_" + TimeToString(FvgTime, TIME_SECONDS);

        // Set rectangle coordinates
        datetime FvgStartTime = iTime(SymbolArray[SymbolLoop], Period(), 2);
        datetime FvgEndTime = iTime(SymbolArray[SymbolLoop], Period(), 0);

        // Draw the rectangle for FVG using global variables
        ObjectCreate(ChartID(), FvgObjectName, OBJ_RECTANGLE, 0, FvgStartTime, FvgHigh, FvgEndTime, FvgLow);
        ObjectSetInteger(ChartID(), FvgObjectName, OBJPROP_COLOR, IsBullishFVG ? LimeGreen : Red);
        ObjectSetInteger(ChartID(), FvgObjectName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(ChartID(), FvgObjectName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(ChartID(), FvgObjectName, OBJPROP_BACK, true);

        Print("FVG plotted: ", FvgObjectName, " High: ", FvgHigh, " Low: ", FvgLow, " Time: ", TimeToString(FvgTime));
    }
}

//+------------------------------------------------------------------+
//| Set up ATR Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool AtrHandleMultiSymbol()
{
    for (int SymbolLoop = 0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
    {
        ResetLastError();
        AtrHandle[SymbolLoop] = iATR(SymbolArray[SymbolLoop], Period(), AtrPeriod);
        if (AtrHandle[SymbolLoop] == INVALID_HANDLE)
        {
            string OutputMessage = "";
            if (GetLastError() == 4302)
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
    const int StartCandle = 0;
    const int RequiredCandles = 2; // How many candles are required to be stored in Expert

    // Indicator Variables and Buffers
    const int IndexAtr = 0; // ATR Value
    double BufferAtr[];     //[prior,current confirmed,not confirmed]

    // Populate buffers for ATR Value; check errors
    bool FillAtr = CopyBuffer(AtrHandle[SymbolLoop], IndexAtr, StartCandle, RequiredCandles, BufferAtr); // Copy buffer uses oldest as 0 (reversed)
    if (FillAtr == false)
        return (0);

    // Find ATR Value for Candle '1' Only
    double CurrentAtr = NormalizeDouble(BufferAtr[1], 5);

    // Return ATR Value
    return (CurrentAtr);
}

//-----------------------------------------------------------------------+
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
    // Calculate Risk Amount for user
    double minStopLevel = SymbolInfoInteger(CurrentSymbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

    // Set symbol string and variables
    int SymbolDigits = (int)SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS); // note - typecast required to remove error
    double Price = 0.0;
    double StopLossPrice = 0.0;
    double StopLossSize = 1.0;
    double TakeProfitPrice = 0.0;
    double TakeProfitSize = 2.0;

    // Open buy or sell orders
    if (OrderType == ORDER_TYPE_BUY)
    {
        Price = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK), SymbolDigits);
        StopLossPrice = NormalizeDouble(Price - StopLossSize, SymbolDigits);
        TakeProfitPrice = NormalizeDouble(Price + TakeProfitSize, SymbolDigits);
    }
    else if (OrderType == ORDER_TYPE_SELL)
    {
        Price = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_BID), SymbolDigits);
        StopLossPrice = NormalizeDouble(Price + StopLossSize, SymbolDigits);
        TakeProfitPrice = NormalizeDouble(Price - TakeProfitSize, SymbolDigits);
    }

    // Get lot size
    double LotSize = CalculateLotSize();

    // Close any current positions and open new position
    Trade.PositionClose(CurrentSymbol);
    Trade.PositionOpen(CurrentSymbol, OrderType, LotSize, Price, StopLossPrice, TakeProfitPrice, __FILE__);

    // Print successful
    Print("Trade Processed For ", CurrentSymbol, " OrderType ", OrderType, " Lot Size ", LotSize);
    Print("Price: ", Price, " StopLossPrice: ", StopLossPrice, " TakeProfitPrice: ", TakeProfitPrice, " Min Stop Level: ", minStopLevel);

    Print("Calculated Lot Size: ", LotSize);

    return (true);
}

//+------------------------------------------------------------------+
//| Update trailing stop loss and take profit                        |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        string symbol = PositionGetSymbol(i);
        double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
        double stopLoss = PositionGetDouble(POSITION_SL);
        double takeProfit = PositionGetDouble(POSITION_TP);
        double newStopLoss, newTakeProfit;

        Print(" Ticket: ", ticket, " Symbol: ", symbol, "Price: ", price, " StopLossPrice: ", stopLoss, " TakeProfitPrice:", takeProfit);
        // Ensure the symbol is in the tradable symbols
        bool isTradableSymbol = false;
        int SymbolLoop = -1;
        for (int j = 0; j < NumberOfTradeableSymbols; j++)
        {
            if (SymbolArray[j] == symbol)
            {
                isTradableSymbol = true;
                SymbolLoop = j;
                break;
            }
        }

        if (isTradableSymbol)
        {
            double atr = GetAtrValue(SymbolLoop);

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                newStopLoss = price - 1.5 * atr;
                newTakeProfit = price + 1.5 * atr;
                if (newStopLoss > stopLoss)
                {
                    Trade.PositionModify(ticket, newStopLoss, takeProfit);
                    NotifyUser("Trailing Stop Loss updated for " + symbol + " to " + DoubleToString(newStopLoss, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                }
                if (newTakeProfit > takeProfit)
                {
                    Trade.PositionModify(ticket, stopLoss, newTakeProfit);
                    NotifyUser("Trailing Take Profit updated for " + symbol + " to " + DoubleToString(newTakeProfit, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                }
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                newStopLoss = price + 1.5 * atr;
                newTakeProfit = price - 1.5 * atr;
                if (newStopLoss < stopLoss)
                {
                    Trade.PositionModify(ticket, newStopLoss, takeProfit);
                    NotifyUser("Trailing Stop Loss updated for " + symbol + " to " + DoubleToString(newStopLoss, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                }
                if (newTakeProfit < takeProfit)
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
