/*
 * CUPS raster filter for the Elgin i9 (ESC/POS, 80mm, 203 dpi).
 *
 * Reads CUPS raster (8-bit gray or 24-bit RGB), optionally crops the white
 * margins and scales the content to the paper width, thresholds it to 1 bit
 * and sends it as ESC/POS "GS v 0" raster bands, then feeds and cuts.
 *
 * Options (PPD): ElginCut, ElginBand, ElginDelay, ElginShift, ElginFit.
 *
 * Build: clang -O2 -o rastertoelgini9 rastertoelgini9.c -lcups -lm
 */

#include <cups/cups.h>
#include <cups/raster.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OUT_W      576  /* dots across: 72mm at 203 dpi */
#define OUT_BYTES  (OUT_W / 8)
#define TAIL_ROWS  24   /* blank rows kept after the last printed row */
#define TOP_ROWS   4    /* blank rows kept before the content when fitting */
#define EDGE_PAD   4    /* minimum blank dots on each side when fitting */
#define THRESHOLD  128

static void
put(const unsigned char *data, size_t len)
{
  fwrite(data, 1, len, stdout);
}

/* Feed in raster dots, avoiding firmware-dependent motion-unit commands. */
static void
finish_receipt(const char *cut, int feed_mm, int band_rows, int delay_ms)
{
  unsigned char blank[OUT_BYTES] = {0};
  int dots = (int)lround(feed_mm * 203.0 / 25.4);
  while (dots > 0) {
    int n = dots < band_rows ? dots : band_rows;
    unsigned char hdr[8] = {0x1d, 'v', '0', 0, OUT_BYTES, 0, n, 0};
    put(hdr, sizeof(hdr));
    for (int y = 0; y < n; y++) put(blank, sizeof(blank));
    fflush(stdout);
    if (delay_ms) usleep((useconds_t)delay_ms * 1000);
    dots -= n;
  }
  if (!strcmp(cut, "Full"))
    put((const unsigned char *)"\x1d" "VA\x00", 4);
  else if (!strcmp(cut, "None"))
    put((const unsigned char *)"\x1b" "d\x04", 3);
  else
    put((const unsigned char *)"\x1d" "VB\x00", 4);
}

/* Luminance 0..255, 255 = white. */
static int
luma(const unsigned char *line, int x, const cups_page_header2_t *h)
{
  int v;

  if (h->cupsBitsPerPixel == 24)
  {
    const unsigned char *p = line + 3 * x;
    return (p[0] * 30 + p[1] * 59 + p[2] * 11) / 100;
  }

  v = line[x];
  return h->cupsColorSpace == CUPS_CSPACE_K ? 255 - v : v;
}

/* Bilinear sample of the gray image; outside the image is white. */
static int
sample(const unsigned char *g, int w, int h, double xs, double ys)
{
  int    x0, y0, x1, y1;
  double fx, fy, top, bot;

  if (xs < 0 || ys < 0 || xs > w - 1 || ys > h - 1)
    return 255;

  x0 = (int)xs;  y0 = (int)ys;
  x1 = x0 + 1 < w ? x0 + 1 : x0;
  y1 = y0 + 1 < h ? y0 + 1 : y0;
  fx = xs - x0;  fy = ys - y0;

  top = g[(size_t)y0 * w + x0] * (1 - fx) + g[(size_t)y0 * w + x1] * fx;
  bot = g[(size_t)y1 * w + x0] * (1 - fx) + g[(size_t)y1 * w + x1] * fx;
  return (int)(top * (1 - fy) + bot * fy + 0.5);
}

int
main(int argc, char *argv[])
{
  int                 fd = 0, page = 0;
  cups_raster_t       *ras;
  cups_page_header2_t h;
  cups_option_t       *opts = NULL;
  int                 nopts;
  const char          *cut, *fit, *v;
  int                 band_rows, delay_ms, shift;
  int feed_mm = 0, save_bottom = 1, job_cut = 0, printed = 0;

  if (argc < 6 || argc > 7)
  {
    fprintf(stderr, "ERROR: %s job-id user title copies options [file]\n",
            argv[0]);
    return 1;
  }

  if (argc == 7 && (fd = open(argv[6], O_RDONLY)) < 0)
  {
    perror("ERROR: Unable to open raster file");
    return 1;
  }

  nopts = cupsParseOptions(argv[5], 0, &opts);
  cut = cupsGetOption("ElginCut", nopts, opts);
  if (!cut)
    cut = "Partial";
  fit = cupsGetOption("ElginFit", nopts, opts);
  if (!fit)
    fit = "Content";

  /* Small bands plus a pause let the printer's buffer drain; without it the
     network module can drop everything but the last band. */
  band_rows = (v = cupsGetOption("ElginBand", nopts, opts)) ? atoi(v) : 64;
  delay_ms  = (v = cupsGetOption("ElginDelay", nopts, opts)) ? atoi(v) : 30;
  /* The print head sits off-center on 79mm paper: dots 0..575 start ~5mm from
     the left edge and end ~2mm from the right. Shifting the content left by
     this many dots centers it on the paper. */
  shift     = (v = cupsGetOption("ElginShift", nopts, opts)) ? atoi(v) : 12;
  if (band_rows < 8 || band_rows > 255)
    band_rows = 64;
  if (delay_ms < 0)
    delay_ms = 0;
  if (shift < 0 || shift > 40)
    shift = 12;

  v = cupsGetOption("ElginFeed", nopts, opts);
  if (v) {
    char *end;
    long mm = strtol(v, &end, 10);
    if (*v && !*end && mm >= 0 && mm <= 30) feed_mm = (int)mm;
  }
  v = cupsGetOption("ElginSaveBottom", nopts, opts);
  save_bottom = !v || strcmp(v, "Off");
  v = cupsGetOption("ElginFinishScope", nopts, opts);
  job_cut = v && !strcmp(v, "Job");

  ras = cupsRasterOpen(fd, CUPS_RASTER_READ);
  if (!ras)
  {
    fputs("ERROR: Unable to open raster stream\n", stderr);
    return 1;
  }

  put((const unsigned char *)"\x1b@", 2); /* ESC @: initialize */

  while (cupsRasterReadHeader2(ras, &h))
  {
    int           width = h.cupsWidth, height = h.cupsHeight;
    int           y, x, minx = width, maxx = -1, miny = height, maxy = -1;
    int           out_h, ytop, copies, c, dark = 0;
    double        s, x0, y0, pad_l;
    unsigned char *line, *gray, *out;

    if (!((h.cupsBitsPerPixel == 8 && h.cupsNumColors == 1) ||
          h.cupsBitsPerPixel == 24))
    {
      fprintf(stderr, "ERROR: Unsupported raster format (%u bpp)\n",
              h.cupsBitsPerPixel);
      return 1;
    }

    page++;
    fprintf(stderr, "PAGE: %d 1\n", page);

    line = malloc(h.cupsBytesPerLine);
    gray = malloc((size_t)width * height);
    if (!line || !gray)
    {
      fputs("ERROR: Out of memory\n", stderr);
      return 1;
    }

    for (y = 0; y < height; y ++)
    {
      unsigned char *row = gray + (size_t)y * width;

      if (cupsRasterReadPixels(ras, line, h.cupsBytesPerLine) == 0)
      {
        memset(row, 255, (size_t)width * (height - y));
        break;
      }

      for (x = 0; x < width; x ++)
      {
        row[x] = (unsigned char)luma(line, x, &h);
        if (row[x] < THRESHOLD)
        {
          dark = 1;
          if (x < minx) minx = x;
          if (x > maxx) maxx = x;
          if (y < miny) miny = y;
          if (y > maxy) maxy = y;
        }
      }
    }

    if (!dark)
    {
      free(line);
      free(gray);
      continue;
    }

    if (strcmp(fit, "None"))
    {
      /* Crop the white margins and scale the content to the paper width. */
      int    cw = maxx - minx + 1, ch = maxy - miny + 1;
      double target = 2.0 * (OUT_W / 2 - shift) - 2 * EDGE_PAD;

      s     = target / cw;
      x0    = minx;
      y0    = miny;
      pad_l = OUT_W / 2 - shift - cw * s / 2.0;
      ytop  = TOP_ROWS;
      out_h = ytop + (int)ceil((save_bottom ? ch : height - miny) * s) + TAIL_ROWS;
    }
    else
    {
      s     = 1.0;
      x0    = 0;
      y0    = 0;
      pad_l = -shift;
      ytop  = 0;
      out_h = save_bottom ? maxy + 1 + TAIL_ROWS : height;
    }

    out = calloc((size_t)out_h, OUT_BYTES);
    if (!out)
    {
      fputs("ERROR: Out of memory\n", stderr);
      return 1;
    }

    for (y = 0; y < out_h; y ++)
    {
      double ys = y0 + (y - ytop) / s;

      for (x = 0; x < OUT_W; x ++)
      {
        double xs = x0 + (x - pad_l) / s;

        if (sample(gray, width, height, xs, ys) < THRESHOLD)
          out[(size_t)y * OUT_BYTES + x / 8] |= 0x80 >> (x % 8);
      }
    }

    copies = h.NumCopies > 0 ? (int)h.NumCopies : 1;

    for (c = 0; c < copies; c ++)
    {
      for (y = 0; y < out_h; y += band_rows)
      {
        int           n = out_h - y < band_rows ? out_h - y : band_rows;
        unsigned char hdr[8] = {0x1d, 'v', '0', 0,
                                OUT_BYTES & 0xff, OUT_BYTES >> 8,
                                n & 0xff, n >> 8};

        put(hdr, sizeof(hdr));
        put(out + (size_t)y * OUT_BYTES, (size_t)n * OUT_BYTES);
        fflush(stdout);
        if (delay_ms)
          usleep((useconds_t)delay_ms * 1000);
      }

      printed = 1;
      if (!job_cut) finish_receipt(cut, feed_mm, band_rows, delay_ms);
    }

    free(line);
    free(gray);
    free(out);
  }

  if (job_cut && printed) finish_receipt(cut, feed_mm, band_rows, delay_ms);
  fflush(stdout);
  if (ferror(stdout)) { cupsRasterClose(ras); return 1; }
  cupsRasterClose(ras);
  return 0;
}
