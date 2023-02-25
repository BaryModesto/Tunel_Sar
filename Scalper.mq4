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
input string Separador_MM = "---------------------Media Movil";
extern int Periodo_Media_Movil = 50;
extern ENUM_MA_METHOD tipo_de_Media = MODE_EMA;
extern ENUM_APPLIED_PRICE tipo_de_precio = PRICE_CLOSE;
//---
//input string Separador_Gestion = "---------------------Gestion";
//extern double Porcentaje_Diario_Ganancia = 0,
//              Porcentaje_Diario_Perdida = 0,
//              Porcentaje_Ganancia = 0,
//              Porcentaje_Perdida = 0;
//---
input string Peparador_Horario = "---------------------Horario";
extern bool Restringir_Horario = false;
extern string Hora_Inicial = "10:32";
extern string Hora_Final = "12:42";
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
     bloqueo = false,
     luz_verde = false,
     flag = true;
//double balance_de_referencia,
//       balance_global,
//       balance_ref_diario,
//       ganancia_robot = 0,
//       perdida_total = 0,
//       comisiones = 0;
datetime vencimiento = D'2023.03.7',
         //comprobacion_diaria = 0,
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
   if(TimeCurrent() > vencimiento)
   {
      Alert("Tiempo de prueba finalizado");
      ExpertRemove();
   }
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
//|   Gestion de Alerta Roja                                                               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//---Indicar direccion de operacion
//+------------------------------------------------------------------+
   if(
      ( TimeCurrent() >= Convertir_Str_Hora_del_Broker(Hora_Inicial) && TimeCurrent() <= Convertir_Str_Hora_del_Broker(Hora_Final)
        && Restringir_Horario && luz_verde && !bloqueo)
      ||
      (!Restringir_Horario && luz_verde && !bloqueo)
   )
   {
   }
//+------------------------------------------------------------------+
//|        Abrir Operaciones
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Mostrar valores en la pantalla                                                                 |
//+------------------------------------------------------------------+
   Comment(
      "Balance Actual   ", NormalizeDouble (AccountBalance(), 2), "\n",
      "Flotante del Robot  ",  NormalizeDouble (Profit_Actual(6, num_mag), 2), "\n",
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
//| Telegram Comunicacion                                                                 |
//+------------------------------------------------------------------+
/*const string telegram_bot_token = "5485504177:AAGkKvfqmD9AogTsLf743wY0Ok0h6_Z14PE";
const string ChatId= " -1001718739597";
const string Telegram_API_URL = "https://api.telegram.org";  //Añadir esto a Allow URLs
 Telegram_Enviar_Mensaje(Telegram_API_URL,telegram_bot_token,ChatId,"EURUSD Compra");//llamada a funcion*/
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
