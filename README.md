## Se usará el indicador "besar 01-" para la visualizacion del canal de tendencia
* Buffer 0: indica el valor de la Banda Media
* Buffer 1: indica el valor de la Banda Superior
* Buffer 2: indica el valor de la Banda Inferior
## Se usará el indicador "PARA" para la visualizacion del Parabolic SAR
* Buffer 0: indica el valor deL SAR de arriba (el utilizado para ventas)
* Buffer 1: indica el valor deL SAR de abajo (el utilizado para compras)

---
# Descrpicion del proceso de entrada

1. El precio toca o sobresale el canal (por encima o por debajo), para arrojar la direccion de la futura operacion.
2. Analizar si el Parabolic SAR se encuentra al 50% o mas de la banda del canal para confirmar posible entrada.
    * caso BUY: el Sar Bajista (rojo) debe estar en medio o mas abajo de la banda de inferior del canal.
    * caso SELL: el Sar Alcista (azul) debe estar en medio o mas arriba de la banda de superior del canal.
3. Esperar a que surja un Parabolic SAR a favor de la direccion de la futura operacion, en ese momento abrir la operacion.
    *  La operacion se abre con una Orden SELL_STOP o BUY_STOP segun sea el caso, a X pips del precio Bid o Ask.
    * El Stop Loss (SL) se coloca en el maximo o minimo, segun sea el caso (Sell o Buy).
    * El Take Profit se coloca a un ratio establecido por el trader.  