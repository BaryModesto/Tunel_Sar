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
extern double Pips_Ordenes_Stop = 1;

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
//--- valores del indicador Parabolic SAR
   double sar_bajista_up = iCustom(_Symbol, _Period, "PARA", _sar1, _sar2, _sar3, 0, 1); //rojo
   double sar_alcista_down = iCustom(_Symbol, _Period, "PARA", _sar1, _sar2, _sar3, 1, 1);//azul
//--- valores del indicador Canal
   double canal_medio = iCustom(_Symbol, _Period, "besar 01-", _canal1, _canal2, _canal3, _canal4, _canal5,
                                _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, 0, 1);
   Crear_Linea_Horizontal("canal_medio", canal_medio, clrPink, 1);
   double canal_up = iCustom(_Symbol, _Period, "besar 01-", _canal1, _canal2, _canal3, _canal4, _canal5,
                             _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, 1, 1);
   Crear_Linea_Horizontal("canal_up", canal_up, clrPink, 1);
   double canal_dowm = iCustom(_Symbol, _Period, "besar 01-", _canal1, _canal2, _canal3, _canal4, _canal5,
                               _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, _canal_resto, 2, 1);
   Crear_Linea_Horizontal("canal_dowm", canal_dowm, clrPink, 1);
   double mitad_banda_superior = NormalizeDouble( (canal_up + canal_medio) / 2, _Digits ) ;
   Crear_Linea_Horizontal("mitad_banda_superior", mitad_banda_superior, clrDarkGoldenrod, 1, STYLE_DOT);
   double mitad_banda_inferior = NormalizeDouble( (canal_dowm + canal_medio) / 2, _Digits ) ;
   Crear_Linea_Horizontal("mitad_banda_inferior", mitad_banda_inferior, clrDarkGoldenrod, 1, STYLE_DOT);
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
        && Restringir_Horario /*&& luz_verde && !bloqueo */ )
      ||
      (!Restringir_Horario /*&& luz_verde && !bloqueo */ )
   )
   {
      //--- Paso 1
      if(Bid <= canal_dowm && !futura_compra_1)      //Si el precio esta en la parte baja del canal
      {
         Reiniciar_Pasos();
         direccion = nada;
         futura_compra_1 = true;
         Borrar_Objeto("s");
      }
      else if(Ask >= canal_up && !futura_venta_1)    //Si el precio esta en la parte alta del canal
      {
         Reiniciar_Pasos();
         direccion = nada;
         futura_venta_1 = true;
         Borrar_Objeto("b");
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
         //Print("bbbbbbbbbbbbb");
         //Crear_Linea_Horizontal("b", Bid, clrBlue);
      }
      else if(futura_venta_2 && sar_bajista_up != 0 && sar_alcista_down == 0  && direccion == nada)      //Abrir venta
      {
         direccion = sell;
         //Print("sssssssssssssss");
         //Crear_Linea_Horizontal("s", Bid, clrCrimson);
      }
   }
//+------------------------------------------------------------------+
//|        Abrir Operaciones
//+------------------------------------------------------------------+
   if(direccion == buy)
   {
      Crear_Linea_Horizontal("b", Bid, clrBlue);
      Reiniciar_Pasos();
   }
   else if(direccion == sell)
   {
      Crear_Linea_Horizontal("s", Bid, clrCrimson);
      Reiniciar_Pasos();
   }
//+------------------------------------------------------------------+
//| Mostrar valores en la pantalla                                                                 |
//+------------------------------------------------------------------+
   Comment(
      "\n",
      "mitad_banda_superior ", DoubleToString(mitad_banda_superior, _Digits), "\n",
      "mitad_banda_inferior ", DoubleToString(mitad_banda_inferior, _Digits), "\n",
      "\n",
      "futura_venta_1  ", futura_venta_1, "\n",
      "futura_venta_2  ", futura_venta_2, "\n",
      "futura_compra_1  ", futura_compra_1, "\n",
      "futura_compra_2  ", futura_compra_2, "\n",
      "\n",
      "SAR bajista", sar_bajista_up, "\n",
      "SAR alcista", sar_alcista_down, "\n",
      "direccion ", EnumToString(direccion), "\n",
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
}
//+------------------------------------------------------------------+
