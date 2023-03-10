/*
   joker
*/
#property copyright "joker"
#property link      ""

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Red
#property indicator_color2 Blue

double g_ibuf_76[];
double g_ibuf_80[];
extern double Step = 0.013;
extern double Maximum = 0.2;
extern int Precision = 5;

int init() {
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 2);
   SetIndexStyle(1, DRAW_ARROW, EMPTY, 2);
   SetIndexBuffer(0, g_ibuf_76);
   SetIndexBuffer(1, g_ibuf_80);
   SetIndexArrow(0, 158);
   SetIndexArrow(1, 158);
   IndicatorShortName("PARA");
   SetIndexLabel(0, " Up Channel");
   SetIndexLabel(1, " Down Channel");
   SetIndexDrawBegin(0, 2);
   SetIndexDrawBegin(1, 2);
   return (0);
}

int deinit() {
   return (0);
}

int start() {
   double ld_12;
   int li_4 = IndicatorCounted();
   if (li_4 < 0) li_4 = 0;
   if (li_4 > 0) li_4--;
   int li_0 = Bars - li_4;
   for (int li_8 = 0; li_8 < li_0; li_8++) {
      ld_12 = NormalizeDouble(iSAR(Symbol(), 0, Step, Maximum, li_8), Precision);
      if (ld_12 >= iHigh(Symbol(), 0, li_8)) {
         g_ibuf_76[li_8] = ld_12;
         g_ibuf_80[li_8] = 0;
      } else {
         g_ibuf_76[li_8] = 0;
         g_ibuf_80[li_8] = ld_12;
      }
   }
   return (0);
}
