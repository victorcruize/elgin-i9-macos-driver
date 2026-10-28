#include <cups/raster.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
  int pages = argc > 1 ? atoi(argv[1]) : 2;
  int blank = argc > 2 ? atoi(argv[2]) : 0;
  cups_raster_t *r = cupsRasterOpen(1, CUPS_RASTER_WRITE);
  for (int p = 0; p < pages; p++) {
    cups_page_header2_t h = {0};
    h.cupsWidth = 576; h.cupsHeight = 200; h.cupsBytesPerLine = 576;
    h.cupsBitsPerPixel = h.cupsBitsPerColor = 8;
    h.cupsNumColors = 1; h.cupsColorSpace = CUPS_CSPACE_SW;
    h.HWResolution[0] = h.HWResolution[1] = 203; h.NumCopies = 1;
    if (!cupsRasterWriteHeader2(r, &h)) return 1;
    for (int y = 0; y < 200; y++) {
      unsigned char line[576]; memset(line, 255, sizeof(line));
      if (!blank && y >= 10 && y < 30) memset(line + 16, 0, 544);
      if (cupsRasterWritePixels(r, line, sizeof(line)) != sizeof(line)) return 1;
    }
  }
  cupsRasterClose(r);
  return 0;
}
