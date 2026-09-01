//+------------------------------------------------------------------+

//| AccountManager.mq5 |

//| Account Manager Ultra-Rapide - Historique natif & Temps Réel |

//+------------------------------------------------------------------+

#property copyright "Fx FireBird"

#property link "https://t.me/fxfirebird"

#property version "2.00"

#property strict



//--- Inputs

input double DailyProfitTarget = 1300.0; // Profit journalier cible en $
input double   DailyProfitForSpecific = 17.0;      // Profit journalier cible (Actifs Spécifiques) en $

input double DailyLossTarget = 999.0; // Perte journalière max en $ (ex: 50 pour -50$)
input bool   UseTimeFilter = false;    // Activer le filtre d'heures (True = Oui, False = Non)

input string StartTime = "00:00"; // Heure de début de trading (HH:MM)

input string EndTime = "23:59"; // Heure de fin de trading (HH:MM) - Clôture & Blocage

input string BlockFileName = "TRADING_BLOCKED"; // Flag pour autres EA

input string SpecificAssets = "Step Index, XAUUSD"; // Actifs ciblés séparés par des virgules (vide = tous)



//--- Variables globales

datetime currentDayStart = 0;

bool isBlocked_Specific = false;

bool isBlocked_Others = false;

string g_blockFile_Specific;

string g_blockFile_Others;

string g_targetAssets[];

int g_targetAssetsCount = 0;



//+------------------------------------------------------------------+

//| Expert initialization function |

//+------------------------------------------------------------------+

int OnInit()

{

g_blockFile_Specific = BlockFileName + "_SPECIFIC.txt";

g_blockFile_Others = BlockFileName + "_OTHERS.txt";

currentDayStart = GetDayStart(TimeCurrent());


if(SpecificAssets == "") g_targetAssetsCount = 0;

else

{

g_targetAssetsCount = StringSplit(SpecificAssets, ',', g_targetAssets);

for(int i = 0; i < g_targetAssetsCount; i++)

{

StringTrimLeft(g_targetAssets[i]);

StringTrimRight(g_targetAssets[i]);

StringToUpper(g_targetAssets[i]);

}

}


// Vérification initiale du blocage horaire
if(UseTimeFilter && !IsWithinTradingHours())
{
Print("[INIT] Hors plage horaire (", StartTime, " - ", EndTime, "). Clôture et blocage.");

CloseGroupPositions(true); DeleteGroupPendingOrders(true);

CloseGroupPositions(false); DeleteGroupPendingOrders(false);


isBlocked_Specific = true; isBlocked_Others = true;

CreateGroupBlockFile("OUT_OF_HOURS", true);

CreateGroupBlockFile("OUT_OF_HOURS", false);

}

else

{

// Réinitialisation si nouvelle session

RemoveGroupBlockFile(true);

RemoveGroupBlockFile(false);

isBlocked_Specific = false; isBlocked_Others = false;

}


Print("Account Manager V2 (Dual-Target Ultra-Fast) initialisé avec succès.");

return(INIT_SUCCEEDED);

}

//+------------------------------------------------------------------+

//| Expert deinitialization function |

//+------------------------------------------------------------------+

void OnDeinit(const int reason)

{

}



//+------------------------------------------------------------------+

//| Expert tick function |

//+------------------------------------------------------------------+

void OnTick()

{

datetime todayStart = GetDayStart(TimeCurrent());


//--- 1. Réinitialisation sur changement de jour (00:00)

if(todayStart > currentDayStart)

{

currentDayStart = todayStart;

isBlocked_Specific = false;

isBlocked_Others = false;

RemoveGroupBlockFile(true);

RemoveGroupBlockFile(false);

Print(">>> NOUVEAU JOUR DÉTECTÉ : ", TimeToString(currentDayStart, TIME_DATE));

}


//--- 2. Vérification horaire ultra-rapide
if(UseTimeFilter && !IsWithinTradingHours())
{
if(!isBlocked_Specific) { Print("*** HEURE DE FIN (SPECIFIC) -> Clôture immédiate ***"); ExecuteGroupClosureAndBlock("OUT_OF_HOURS", true); }
if(!isBlocked_Others) { Print("*** HEURE DE FIN (OTHERS) -> Clôture immédiate ***"); ExecuteGroupClosureAndBlock("OUT_OF_HOURS", false); }
return;
}


//--- 3. Contrôle des actifs Spécifiques (Ou de TOUS si l'input est vide)

if(!isBlocked_Specific)

{

double closedPnL_S   = GetGroupClosedProfitToday(currentDayStart, true);
      double floatingPnL_S = GetGroupFloatingProfitToday(true);
      double totalPnL_S    = closedPnL_S + floatingPnL_S;

      // ICI : On utilise le nouvel input dédié aux actifs spécifiques
      if(totalPnL_S >= DailyProfitForSpecific)
      {
         Print("*** TARGET PROFIT ATTEINT (SPECIFIC) : +", DoubleToString(totalPnL_S, 2), "$ ***");

ExecuteGroupClosureAndBlock("PROFIT_TARGET_REACHED_SPECIFIC", true);

}

else if(DailyLossTarget > 0 && totalPnL_S <= -MathAbs(DailyLossTarget))

{

Print("*** PERTE MAXIMALE ATTEINTE (SPECIFIC) : ", DoubleToString(totalPnL_S, 2), "$ ***");

ExecuteGroupClosureAndBlock("MAX_LOSS_REACHED_SPECIFIC", true);

}

}



//--- 4. Contrôle des Autres actifs (Seulement si des actifs spécifiques ont été définis)

if(!isBlocked_Others && g_targetAssetsCount > 0)

{

double closedPnL_O = GetGroupClosedProfitToday(currentDayStart, false);

double floatingPnL_O = GetGroupFloatingProfitToday(false);

double totalPnL_O = closedPnL_O + floatingPnL_O;



if(totalPnL_O >= DailyProfitTarget)

{

Print("*** TARGET PROFIT ATTEINT (OTHERS) : +", DoubleToString(totalPnL_O, 2), "$ ***");

ExecuteGroupClosureAndBlock("PROFIT_TARGET_REACHED_OTHERS", false);

}

else if(DailyLossTarget > 0 && totalPnL_O <= -MathAbs(DailyLossTarget))

{

Print("*** PERTE MAXIMALE ATTEINTE (OTHERS) : ", DoubleToString(totalPnL_O, 2), "$ ***");

ExecuteGroupClosureAndBlock("MAX_LOSS_REACHED_OTHERS", false);

}

}

}



//+------------------------------------------------------------------+

//| Calcule le PnL des positions FERMÉES aujourd'hui (Cache RAM MQL5)|

//+------------------------------------------------------------------+

double GetGroupClosedProfitToday(datetime dayStart, bool forSpecific)

{

double profit = 0.0;


if(HistorySelect(dayStart, TimeCurrent()))

{

int totalDeals = HistoryDealsTotal();

for(int i = 0; i < totalDeals; i++)

{

ulong ticket = HistoryDealGetTicket(i);

if(ticket > 0)

{

string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);

if(IsSymbolInList(dealSymbol) != forSpecific) continue;


// Plus de restriction de filtre "OUT" pour inclure les deals "IN" (qui portent les commissions d'ouverture)

profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);

profit += HistoryDealGetDouble(ticket, DEAL_SWAP);

profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);

profit += HistoryDealGetDouble(ticket, DEAL_FEE); // Capture d'éventuels frais annexes du courtier

}

}

}

return profit;

}



//+------------------------------------------------------------------+

//| Calcule le PnL Flottant des positions EN COURS par GROUPE |

//+------------------------------------------------------------------+

double GetGroupFloatingProfitToday(bool forSpecific)

{

double floating = 0.0;

int totalPositions = PositionsTotal();


for(int i = totalPositions - 1; i >= 0; i--)

{

ulong ticket = PositionGetTicket(i);

if(ticket > 0)

{

string posSymbol = PositionGetString(POSITION_SYMBOL);

if(IsSymbolInList(posSymbol) != forSpecific) continue;


floating += PositionGetDouble(POSITION_PROFIT);

floating += PositionGetDouble(POSITION_SWAP);

}

}

return floating;

}



//+------------------------------------------------------------------+

//| Exécution de fermeture d'urgence et blocage par GROUPE |

//+------------------------------------------------------------------+

void ExecuteGroupClosureAndBlock(string reason, bool forSpecific)

{

CloseGroupPositions(forSpecific);

DeleteGroupPendingOrders(forSpecific);


if(forSpecific) isBlocked_Specific = true;

else isBlocked_Others = true;


CreateGroupBlockFile(reason, forSpecific);


string groupName = forSpecific ? "SPECIFIC" : "OTHERS";

Print("*** TRADING BLOQUÉ (", groupName, ") [Raison: ", reason, "] ***");

}



//+------------------------------------------------------------------+

//| Vérification de la plage horaire |

//+------------------------------------------------------------------+

bool IsWithinTradingHours()

{

int startH = 0, startM = 0;

int endH = 23, endM = 59;


ParseTimeString(StartTime, startH, startM);

ParseTimeString(EndTime, endH, endM);


MqlDateTime dt;

TimeToStruct(TimeCurrent(), dt);


int curSec = dt.hour * 3600 + dt.min * 60 + dt.sec;

int startSec = startH * 3600 + startM * 60;

int endSec = endH * 3600 + endM * 60;


if(startSec == endSec) return true;


if(startSec < endSec)

return (curSec >= startSec && curSec < endSec);

else

return (curSec >= startSec || curSec < endSec);

}



//+------------------------------------------------------------------+

//| Parse une chaîne HH:MM |

//+------------------------------------------------------------------+

bool ParseTimeString(string timeStr, int &hour, int &minute)

{

string parts[];

if(StringSplit(timeStr, ':', parts) == 2)

{

hour = (int)StringToInteger(parts[0]);

minute = (int)StringToInteger(parts[1]);

return true;

}

return false;

}



//+------------------------------------------------------------------+

//| Gestion du fichier de blocage par GROUPE |

//+------------------------------------------------------------------+

void CreateGroupBlockFile(string reason, bool forSpecific)

{

string fileName = forSpecific ? g_blockFile_Specific : g_blockFile_Others;

int h = FileOpen(fileName, FILE_WRITE|FILE_COMMON|FILE_TXT);

if(h != INVALID_HANDLE)

{

FileWriteString(h, reason);

FileClose(h);

}


if(forSpecific)

{

if(g_targetAssetsCount == 0) GlobalVariableSet("AM_BLOCK_ALL", 1.0);

else

{

for(int i = 0; i < g_targetAssetsCount; i++)

{

if(g_targetAssets[i] != "") GlobalVariableSet("AM_BLOCK_" + g_targetAssets[i], 1.0);

}

}

}

else

{

GlobalVariableSet("AM_BLOCK_OTHERS", 1.0);

}

}



void RemoveGroupBlockFile(bool forSpecific)

{

string fileName = forSpecific ? g_blockFile_Specific : g_blockFile_Others;

if(FileIsExist(fileName, FILE_COMMON)) FileDelete(fileName, FILE_COMMON);


if(forSpecific)

{

GlobalVariableDel("AM_BLOCK_ALL");

for(int i = 0; i < g_targetAssetsCount; i++)

{

if(g_targetAssets[i] != "") GlobalVariableDel("AM_BLOCK_" + g_targetAssets[i]);

}

}

else

{

GlobalVariableDel("AM_BLOCK_OTHERS");

}

}



//+------------------------------------------------------------------+

//| Retourne le début de la journée à 00:00:00 |

//+------------------------------------------------------------------+

datetime GetDayStart(datetime dt)

{

MqlDateTime t;

TimeToStruct(dt, t);

t.hour = 0;

t.min = 0;

t.sec = 0;

return StructToTime(t);

}



//+------------------------------------------------------------------+

//| Détermine le mode d'exécution supporté par le courtier |

//+------------------------------------------------------------------+

ENUM_ORDER_TYPE_FILLING GetFillingMode(string symbol)

{

uint filling = (uint)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

if((filling & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;

if((filling & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;

return ORDER_FILLING_RETURN;

}



//+------------------------------------------------------------------+

//| Clôture ultra-rapide des positions par GROUPE |

//+------------------------------------------------------------------+

void CloseGroupPositions(bool forSpecific)

{

for(int i = PositionsTotal() - 1; i >= 0; i--)

{

ulong ticket = PositionGetTicket(i);

if(ticket == 0) continue;


string symbol = PositionGetString(POSITION_SYMBOL);

if(IsSymbolInList(symbol) != forSpecific) continue;


double volume = PositionGetDouble(POSITION_VOLUME);

ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);


double price = (posType == POSITION_TYPE_BUY)

? SymbolInfoDouble(symbol, SYMBOL_BID)

: SymbolInfoDouble(symbol, SYMBOL_ASK);


MqlTradeRequest req = {};

MqlTradeResult res = {};

req.action = TRADE_ACTION_DEAL;

req.position = ticket;

req.symbol = symbol;

req.volume = volume;

req.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;

req.price = price;

req.deviation = 10;

req.type_filling = GetFillingMode(symbol);


if(!OrderSend(req, res)) Print("Erreur de fermeture (Position ", ticket, ") : ", GetLastError());

}

}



//+------------------------------------------------------------------+

//| Suppression ultra-rapide des ordres en attente par GROUPE |

//+------------------------------------------------------------------+

void DeleteGroupPendingOrders(bool forSpecific)

{

for(int i = OrdersTotal() - 1; i >= 0; i--)

{

ulong ticket = OrderGetTicket(i);

if(ticket == 0) continue;


string symbol = OrderGetString(ORDER_SYMBOL);

if(IsSymbolInList(symbol) != forSpecific) continue;


MqlTradeRequest req = {};

MqlTradeResult res = {};

req.action = TRADE_ACTION_REMOVE;

req.order = ticket;


if(!OrderSend(req, res)) Print("Erreur de suppression (Ordre ", ticket, ") : ", GetLastError());

}

}

//+------------------------------------------------------------------+

//| Vérifie si l'actif est dans la liste (Insensible à la casse) |

//+------------------------------------------------------------------+

bool IsSymbolInList(string symbol)

{

if(g_targetAssetsCount == 0) return true;


string symUpper = symbol;

StringToUpper(symUpper);


for(int i = 0; i < g_targetAssetsCount; i++)

{

if(g_targetAssets[i] == symUpper) return true;

}

return false;

}

//+-------------------------------------------------------------------+