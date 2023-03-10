//+------------------------------------------------------------------+
//|                                                      Scalper.mq4 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#define  ESPERA  250
//+------------------------------------------------------------------+
//| Includes                                                          |
//+------------------------------------------------------------------+
#include <Robapips\Chivos.mqh>
#include <Robapips\Objetos.mqh>
#include <Robapips\Operaciones.mqh>
#include <Robapips\Velas.mqh>
#include <Robapips\DEFINES.mqh>
Operaciones op;
Velas vv;
//+------------------------------------------------------------------+
//|      ENUM                                                                  |
//+------------------------------------------------------------------+

enum ENUM_MODO
{
   Automatico,
   Manual,
};
enum ENUM_DIR
{
   nada,
   buy,
   sell,
};
//+------------------------------------------------------------------+
//|    ESTRUCTURAS                                                              |
//+------------------------------------------------------------------+
struct Datos_OP
{
   bool              BE_realizado;
   bool              TS_realizado;
   ushort            parcial_cerrado;
   int               ticket;
   //---Constructor
                     Datos_OP()
   {
      BE_realizado = false;
      TS_realizado = false;
      parcial_cerrado = 0;
      ticket = 0;
   };
} info_op[];
//+------------------------------------------------------------------+
//|      Entradas de valores
//+------------------------------------------------------------------+
input string Separador_Operativa = "---------------------Operativa";
extern double Pips_Ordenes_Stop = 1,
              Take_Profit_Fixed = 0.5,
              Fixed_Lots = 0,
              Risk_Porcent = 1,
              Cost_Per_Lots = 3.5;
//---
//input string Separador_Gestion = "---------------------Gestion";
//extern double Porcentaje_Diario_Ganancia = 0,
//              Porcentaje_Diario_Perdida = 0,
//              Porcentaje_Ganancia = 0,
//              Porcentaje_Perdida = 0;
//---
input string Separador_Horario = "---------------------Horario";
extern bool Restringir_Horario = false;
extern string START_TRADING_HOUR = "05:30";
extern string END_TRADING_HOUR = "20:45";
//extern string Dias_Habiles = "1,2,3,4,5";
//---
input string Separador_Extras = "---------------------Extras";
extern bool Indice = false;
input int num_mag = 0;

//+------------------------------------------------------------------+
//|                         Variables Globales                                         |
//+------------------------------------------------------------------+
ENUM_DIR  direccion = nada;
string line_BE = "BE",
       linea_tp_dinamic = "TP_dinamico",
       linea_TS = "trailing_stop";
int   cantidad_velas = 0,
      //cuentas_validas[2] = {284731, 7778072},
      //                     dias[6],
      ticket_ref[];
char  cant_graf[TODAS_OP],
      cant_ref[TODAS_OP],
      eventos_op[CANT_EVENTOS];
bool diapason = true,
     parametros_input = false,
     //bloqueo = false,
     //luz_verde = false,
     futura_compra_1 = false,
     futura_venta_1 = false,
     futura_compra_2 = false,
     futura_venta_2 = false,
     flag = true;
//--- valores de parametros de entrada de Parabolic SAR
const double _sar1 = 0.013,
             _sar2 = 0.2;
const int _sar3 = 5;
//--- valores de parametros de entrada de Canal
const string _canal1 = "current time frame";
const int _canal2 = 56,
          _canal3 = 6;
const double _canal4 = 2.5;
const bool _canal5 = false,
           _canal_resto = false;
//---
//double balance_de_referencia,
//       balance_global,
//       balance_ref_diario,
//       ganancia_robot = 0,
//       perdida_total = 0,
//       comisiones = 0;
datetime //comprobacion_diaria = 0,
         tiempo_1_sop_res = 0,
         tiempo_ref = 0;
MqlDateTime estructura;

//---
//---
//+------------------------------------------------------------------+
//|  Expert initialization function                                                                |
//+------------------------------------------------------------------+
int OnInit()
{
//---
   if(_UninitReason != 3 && _UninitReason != 5) //Lo que quiero que haga solo una vez
   {
      //balance_de_referencia = balance_global = balance_ref_diario = AccountBalance();
      tiempo_ref = TimeCurrent();
      //ArrayInitialize(dias, 0);
      ArrayInitialize(cant_ref, 0);
      ArrayInitialize(cant_graf, 0);
      ArrayInitialize(eventos_op, 0);
//---Parametros iniciales de Operaciones
      op.Set_Numero_Magico(num_mag);
      op.Set_Comentario("@robapips");
   }
//---Parametros iniciales de Media Movil
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   if(_UninitReason != 3 && _UninitReason != 5 && !IsVisualMode())
   {
      Print("Eliminar objetos");
      ObjectsDeleteAll();
   }
   if(_UninitReason == 5)
      parametros_input = true;
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//+------------------------------------------------------------------+
//|     Vencimiento del tiempo de prueba                                                             |
//+------------------------------------------------------------------+
   //if(TimeCurrent() > vencimiento)
   //{
   //   Alert("Tiempo de prueba finalizado");
   //   ExpertRemove();
   //}
//+------------------------------------------------------------------+
//|  Solo una vez                                                                 |
//+------------------------------------------------------------------+
   if(flag == true || parametros_input)
   {
      //Dias_Habiles_Llenar(Dias_Habiles, dias);
      flag = false;
   }
//+------------------------------------------------------------------+
//---Esperar que pase una vela en el grafico para ejecutar
//+------------------------------------------------------------------+
//int nuevas_barras = iBars(_Symbol, _Period);
//if(cantidad_velas < nuevas_barras)
//{
//      diapason = true;
//      cantidad_velas = 0;
//}
//+------------------------------------------------------------------+
//---Valores de variables iniciales que fluctuan con cada Tick
//+------------------------------------------------------------------+
//double media_movil = mm_anterior.Valor_de_Media_Movil();
   double spread = MarketInfo(_Symbol, MODE_SPREAD) * Point;
   double min_lotaje = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
//--- valores del indicador Parabolic SAR
   double sar_bajista_up = iCustom(_Symbol, _Period, "PARA", _sar1, _sar2, _sar3, 0, 0); //rojo
   double sar_alcista_down = iCustom(_Symbol, _Period, "PARA", _sar1, _sar2, _sar3, 1, 0);//azul
//--- valores del indicador Canal
   double canal_medio = iCustom(_Symbol, _Period, "besar 01-", _canal1, _canal2, _canal3, _canal4, _canal5,
                                _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, 0, 0);
//Crear_Linea_Horizontal("canal_medio", canal_medio, clrPink, 1);
   double canal_up = iCustom(_Symbol, _Period, "besar 01-", _canal1, _canal2, _canal3, _canal4, _canal5,
                             _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, 1, 0);
//Crear_Linea_Horizontal("canal_up", canal_up, clrPink, 1);
   double canal_dowm = iCustom(_Symbol, _Period, "besar 01-", _canal1, _canal2, _canal3, _canal4, _canal5,
                               _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, 2, 0);
//Crear_Linea_Horizontal("canal_dowm", canal_dowm, clrPink, 1);
   double mitad_banda_superior = NormalizeDouble( (canal_up + canal_medio) / 2, _Digits ) ;
//Crear_Linea_Horizontal("mitad_banda_superior", mitad_banda_superior, clrDarkGoldenrod, 1, STYLE_DOT);
   double mitad_banda_inferior = NormalizeDouble( (canal_dowm + canal_medio) / 2, _Digits ) ;
//Crear_Linea_Horizontal("mitad_banda_inferior", mitad_banda_inferior, clrDarkGoldenrod, 1, STYLE_DOT);
//+------------------------------------------------------------------+
//|    Restringir Horario de operaciones  Y gestiones                                                              |
//+------------------------------------------------------------------+
   /*
    if(
          (AccountEquity() >= balance_global + (balance_global * Porcentaje_Ganancia / 100) && Porcentaje_Ganancia != 0)
          ||
          (AccountEquity() <= balance_global - (balance_global * Porcentaje_Perdida / 100) && Porcentaje_Perdida != 0)
    )
    {
          op.Cerrar_Orden_u_Ordenes(true);
          bloqueo = true;
          ExpertRemove();
    }
   ---
    if(TimeCurrent() >= comprobacion_diaria )  //se usa dentro del ONTICK, preferentemente al inicio
    {
          Comprobacion_Diaria(comprobacion_diaria);
          Dia_Habil_Comprobacion(luz_verde, dias);
          balance_ref_diario = AccountBalance();
          bloqueo = false; //Acceder al algoritmo
    }
    else if(TimeCurrent() < comprobacion_diaria &&
                ( (AccountBalance() >= balance_ref_diario + (balance_ref_diario * Porcentaje_Diario_Ganancia / 100) && !bloqueo && Porcentaje_Diario_Ganancia != 0)
                  ||
                  (AccountBalance() <= balance_ref_diario - (balance_ref_diario * Porcentaje_Diario_Perdida / 100) && !bloqueo && Porcentaje_Diario_Perdida != 0)
                )
           )
    {
          bloqueo = true; //Bloquear el acceso al algoritmo
          //Crear_Linea_Vertical("BLOQUEO", Time[0], clrBlack, 4);
    }
    */
//+------------------------------------------------------------------+
//|    Contador de operaciones                                                              |
//+------------------------------------------------------------------+
   Cantidad_OP_Eventos(cant_graf, cant_ref, eventos_op, num_mag);
//+------------------------------------------------------------------+
//|   Trabajo con el Balance
//+------------------------------------------------------------------+
   /*
      if(cant_graf[OP_GRAF] == 0 )
      {
         double balance_actual = AccountBalance();
         perdida_total = 0;
         if(balance_actual < balance_de_referencia)
         {
            perdida_total = MathAbs(balance_de_referencia - balance_actual);
         }
         else
         {
            balance_de_referencia = AccountBalance();
            perdida_total = 0;
         }
      }
   */
//---
//if(eventos_op[OP_CERRADA])
//   Acumular_Balance_Robot(ganancia_robot, tiempo_ref, ticket_ref, num_mag);
//+------------------------------------------------------------------+
//|      Restricciones por Dia
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//---Break Even
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|     Trailing Stop                                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//---Cerrar la Operacion
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  Gestion de Proteccion                                                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|   Reiniciar Arreglo
//+------------------------------------------------------------------+
   if(cant_graf[OP_GRAF] == 0)      //Si no hay ninguna operacion pendiente o activa
   {
      ArrayFree(info_op);              //reinicio el arreglo
   }
//+------------------------------------------------------------------+
//---Indicar direccion de operacion
//+------------------------------------------------------------------+
   if(
      ( TimeCurrent() >= Convertir_Str_Hora_del_Broker(START_TRADING_HOUR) && TimeCurrent() <= Convertir_Str_Hora_del_Broker(END_TRADING_HOUR)
        && Restringir_Horario /*&& luz_verde && !bloqueo */ )
      ||
      (!Restringir_Horario /*&& luz_verde && !bloqueo */ )
   )
   {
      //--- Paso 1
      if(Bid <= canal_dowm && !futura_compra_1)      //Si el precio esta en la parte baja del canal
      {
         Reiniciar_Pasos();
         Quitar_Ordenes_Stop();                       //Eliminar las ordenes pendientes que no se hallan activado
         direccion = nada;
         futura_compra_1 = true;
         tiempo_1_sop_res = Time[2];               //Almaceno el 1er tiempo para buscar el sop o res luego.Le doy una holgura de 2 velas por si hay mechaszo
         //Borrar_Objeto("s");
      }
      else if(Ask >= canal_up && !futura_venta_1)    //Si el precio esta en la parte alta del canal
      {
         Reiniciar_Pasos();
         Quitar_Ordenes_Stop();                      //Eliminar las ordenes pendientes que no se hallan activado
         direccion = nada;
         futura_venta_1 = true;
         tiempo_1_sop_res = Time[2];               //Almaceno el 1er tiempo para buscar el sop o res luego.Le doy una holgura de 2 velas por si hay mechaszo
         //Borrar_Objeto("b");
      }
      //--- Paso 2
      //Se cumple la condicion de la ubicacion del SAR respecto a la banda inferior
      if(futura_compra_1 && !futura_compra_2 && sar_bajista_up <= mitad_banda_inferior && sar_bajista_up > 0 )
      {
         futura_compra_2 = true;
         //keybd_event(19, 0, 0, 0);
         //Sleep(10);
         //keybd_event(19, 0, 2, 0);
      }
      //Se cumple la condicion de la ubicacion del SAR respecto a la banda superior
      else if(futura_venta_1 && !futura_venta_2 && sar_alcista_down >= mitad_banda_superior && sar_alcista_down > 0)
      {
         futura_venta_2 = true;
         //keybd_event(19, 0, 0, 0);
         //Sleep(10);
         //keybd_event(19, 0, 2, 0);
      }
      //--- Paso 3
      if(futura_compra_2 && sar_alcista_down != 0 && sar_bajista_up == 0 && direccion == nada)          //Abrir compra
      {
         direccion = buy;
      }
      else if(futura_venta_2 && sar_bajista_up != 0 && sar_alcista_down == 0  && direccion == nada)      //Abrir venta
      {
         direccion = sell;
      }
   }
//+------------------------------------------------------------------+
//|        Abrir Operaciones
//+------------------------------------------------------------------+
   if(direccion == buy)
   {
      double SL_soporte = Soperte_entre_2_times(tiempo_1_sop_res, TimeCurrent());   //se calcula el SL
      double precio_entrada = Ask + (Pips_Ordenes_Stop * 10 * Point);               //Se ve cual sera el precio de entrada
      double resta = MathAbs(precio_entrada - SL_soporte);                          //Calculo de distancia entre SL y precio de apertura
      double TP_op = precio_entrada + (resta * Take_Profit_Fixed);                        //Calculo de TP segun el ratio designado
      int distancia_SL_OP = (int)(resta / Point);                                   //distancia n ticks entre la op y su SL
      //---
      double volumen = Volumen_op(Risk_Porcent, distancia_SL_OP, OP_BUYSTOP, Indice);
      //Print("Bid ", Encontrar_Bid(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE), AccountCurrency()));
      //Print("Comision ", Comision_Dinamica(3.5, Encontrar_Bid(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE), AccountCurrency())));
      int ticket_temp = op.Abrir_Orden_Pendiente(volumen, OP_BUYSTOP, precio_entrada, SL_soporte, TP_op);
      bool j = OrderSelect(ticket_temp, SELECT_BY_TICKET);
      OrderPrint();
      if(ticket_temp > 0)
      {
         ArrayResize(info_op, ArraySize(info_op) + 1);
         info_op[ArraySize(info_op) - 1].ticket = ticket_temp;
      }
      //Crear_Linea_Horizontal("b", Bid, clrBlue);
      Reiniciar_Pasos();
   }
   else if(direccion == sell)
   {
      double SL_resistencia = Resistencia_entre_2_times(tiempo_1_sop_res, TimeCurrent());  //se calcula el SL
      double precio_entrada = Bid - (Pips_Ordenes_Stop * 10 * Point);                      //Se ve cual sera el precio de entrada
      double resta = MathAbs(precio_entrada - SL_resistencia);                                 //Calculo de distancia entre SL y precio de apertura
      double TP_op = precio_entrada - (resta * Take_Profit_Fixed);                               //Calculo de TP segun el ratio designado
      int distancia_SL_OP = (int)(resta / Point);                                   //distancia n ticks entre la op y su SL
      //---
      double volumen = Volumen_op(Risk_Porcent, distancia_SL_OP, OP_SELLSTOP, Indice);
      //Print("Bid ", Encontrar_Bid(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE), AccountCurrency()));
      //Print("Comision ", Comision_Dinamica(3.5, Encontrar_Bid(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE), AccountCurrency())));
      int ticket_temp = op.Abrir_Orden_Pendiente(volumen, OP_SELLSTOP, precio_entrada, SL_resistencia, TP_op);
      bool k = OrderSelect(ticket_temp, SELECT_BY_TICKET);
      OrderPrint();
      if(ticket_temp > 0)
      {
         ArrayResize(info_op, ArraySize(info_op) + 1);
         info_op[ArraySize(info_op) - 1].ticket = ticket_temp;
      }
      //Crear_Linea_Horizontal("s", Bid, clrCrimson);
      Reiniciar_Pasos();
   }
//+------------------------------------------------------------------+
//| Mostrar valores en la pantalla                                                                 |
//+------------------------------------------------------------------+
   Comment(
      "\n",
      //"ArraySize(info_op)  ", ArraySize(info_op), "\n",
      "\n",
      //"direccion ", EnumToString(direccion), "\n",
//"down ", DoubleToString(sar_bajista_down,_Digits), "\n",
//"Ganancia del Robot  ",  NormalizeDouble (ganancia_robot, 2), "\n",
      "  "
   );
}  //Fin OnTick


//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
}
//+------------------------------------------------------------------+
//|  Para solo Visual Mode                                                                |
//+------------------------------------------------------------------+
//if(IsVisualMode() )
//{
//      Print("AccountBalance  ", AccountBalance);
//      Print("ganancia_a_usar  ", ganancia_a_usar);
//      Print("AccountProfit  ", AccountProfit);
//      Print("ganancia_a_usar   ",  AccountBalance()*ganancia_a_usar / 100);
//      keybd_event(19, 0, 0, 0);
//      Sleep(10);
//      keybd_event(19, 0, 2, 0);
//}
//+------------------------------------------------------------------+
//| FUNCIONES                                                               |
//+------------------------------------------------------------------+
void Eliminar_Caja(Datos_OP  & _array[], int _slot, bool _rango = false, int _cantidad = 0)
{
   if(!_rango)
   {
      int nuevo_tamanho = ArraySize(_array) - 1 - _slot ;
      Datos_OP temp[];
      ArrayResize(temp, nuevo_tamanho);
      ArrayCopy(temp, _array, 0, _slot + 1, ArraySize(temp));
      ArrayCopy(_array, temp, _slot);
      ArrayResize(_array, ArraySize(_array) - 1);
   }
   else
   {
      int nuevo_tamanho = ArraySize(_array)  - (_slot + _cantidad) ;
      Datos_OP temp[];
      ArrayResize(temp, nuevo_tamanho);
      ArrayCopy(temp, _array, 0, _slot + _cantidad, ArraySize(temp));
      ArrayCopy(_array, temp, _slot);
      ArrayResize(_array, ArraySize(_array) - _cantidad);
   }
}
//+------------------------------------------------------------------+
void Reiniciar_Pasos()
{
   direccion = nada;
   futura_compra_1 = false;
   futura_compra_2 = false;
   futura_venta_1 = false;
   futura_venta_2 = false;
//--- Si ocurre una nueva condicion y quedo alguna operacion por activarse, entonces se elimina
   if(cant_graf[OP_BUYSTOP] + cant_graf[OP_SELLSTOP] > 0 )
   {
      Quitar_Ordenes_Stop();
   }
}
//+------------------------------------------------------------------+
void Quitar_Ordenes_Stop()
{
   for(int i = ArraySize(info_op) - 1; i >= 0; i--)      //recorrer todas las operacinoes
   {
      bool b = OrderSelect(info_op[i].ticket, SELECT_BY_TICKET);
      if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)    //Si la operacion es una orden_stop
      {
         op.Cerrar_Orden_u_Ordenes(false, OrderType(), info_op[i].ticket);    //la elimino
      }
   }
}
//+------------------------------------------------------------------+
double Volumen_op(double _porcent_riesgo, int _distancia, int _tipo_op, bool _indice)
{
   double riesgo = 0;
   riesgo = AccountBalance() * _porcent_riesgo / 100;
//---
   double lot_a_usar = 0;
   if(Fixed_Lots > 0)
      lot_a_usar = Fixed_Lots;
   else
      lot_a_usar = Lotaje_Comision(riesgo, _distancia, _tipo_op, Cost_Per_Lots);
//---
   return lot_a_usar;
}
//+------------------------------------------------------------------+
double Lotaje_Comision (double _cant_dinero, int _ticks, int _tipo_operacion, double _comision_lote, bool _divisas = true)
{
   double comission = 0.0;
   double comision_total = 0.0;
   double valor_tick = MarketInfo(_Symbol, MODE_TICKVALUE);
   double min_lotaje = SymbolInfoDouble (_Symbol, SYMBOL_VOLUME_MIN);
//---
   if(_tipo_operacion == OP_BUY || _tipo_operacion == OP_BUYLIMIT || _tipo_operacion == OP_BUYSTOP)
   {
      _tipo_operacion = OP_BUY;
   }
   else if(_tipo_operacion == OP_SELL || _tipo_operacion == OP_SELLLIMIT || _tipo_operacion == OP_SELLSTOP)
   {
      _tipo_operacion = OP_SELL;
   }
//---
   double lotaje = _cant_dinero / (_ticks * valor_tick);
//---
   if(_divisas)
   {
      if( AccountCurrency() == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE))
         // Si la moneda base del par es igual a la moneda de la cuenta se usa la comision que introduce el usuario
      {
         comission = _comision_lote;
      }
      else if(AccountCurrency() != SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE))
         // Encontrar el precio bid para calcular la comision
      {
         double bid_price = Encontrar_Bid(SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE), AccountCurrency());
         comission = Comision_Dinamica(_comision_lote, bid_price);
         comision_total = lotaje * comission;
      }
//---
      if(lotaje < min_lotaje)
      {
         lotaje = min_lotaje;
         return lotaje;
      }
      else if((AccountFreeMarginCheck(_Symbol, _tipo_operacion, lotaje) > 0) && ((lotaje * (_ticks * valor_tick)) + comision_total) <= _cant_dinero)
      {
         return lotaje;
      }
      else if((AccountFreeMarginCheck(_Symbol, _tipo_operacion, lotaje) <= 0) || ((lotaje * (_ticks * valor_tick)) + comision_total) >= _cant_dinero)
      {
         // Print("Disminuyendo el lotaje, pues no alcanza el margen o el riesgo es mayor de lo que se quiere");
         do
         {
            lotaje -= min_lotaje;
         }
         while ((AccountFreeMarginCheck(_Symbol, _tipo_operacion, lotaje) <= 0) || ((lotaje * (_ticks * valor_tick)) + comision_total) > _cant_dinero);
      }
   }
   else
   {
      lotaje /= 10;
      if((AccountFreeMarginCheck(_Symbol, _tipo_operacion, lotaje) > 0) && ((lotaje * (_ticks * valor_tick)) + _comision_lote) <= _cant_dinero)
      {
         return lotaje;
      }
      else if((AccountFreeMarginCheck(_Symbol, _tipo_operacion, lotaje) <= 0) || ((lotaje * (_ticks * valor_tick)) + _comision_lote) >= _cant_dinero)
      {
         //Print("Disminuyendo el lotaje, pues no alcanza el margen o el riesgo es mayor de lo que se quiere");
         do
         {
            lotaje -= min_lotaje;
         }
         while ((AccountFreeMarginCheck(_Symbol, _tipo_operacion, lotaje) <= 0) || ((lotaje * (_ticks * valor_tick)) + _comision_lote) > _cant_dinero);
      }
   }
   return lotaje;
}
//+------------------------------------------------------------------+
double Encontrar_Bid (string _moneda_base, string _moneda_cuenta)
{
   int total_simbolos = SymbolsTotal(false);
   double precio_bid = 0.0;
   string par_encontrado = "";
//---
   for(int i = 0; i <= total_simbolos; i++)
   // Recorrer todos los pares del broker para encontrar el par que contempla la moneda base del par y la moneda de la cuenta
   {
      string nombre_simbolo = SymbolName(i, false);
      if(StringFind(nombre_simbolo, _moneda_base)  >= 0 &&
            StringFind(nombre_simbolo, _moneda_cuenta) >= 0 )
      {
         par_encontrado = nombre_simbolo;
         //Print("par_encontrado ", par_encontrado);
         precio_bid = MarketInfo(par_encontrado, MODE_BID);
      }
   }
  // Print("Bid ", precio_bid);
   return precio_bid;
}
//+------------------------------------------------------------------+
double Comision_Dinamica (double _comision_lot, double _price_bid)
{
   double comision_dinamica = _comision_lot * _price_bid * 2; // El valor 2 es fijo, pero tenemos que mejorar ese calculo
   return comision_dinamica;
}
//+------------------------------------------------------------------+
