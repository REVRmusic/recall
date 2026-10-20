using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Recall.Models;

namespace Recall.Services
{
    /// <summary>
    /// Service d'exportation visuelle haute définition des statistiques du mix (Set Recap)
    /// pour Windows sous forme d'image PNG optimisée pour le partage et les réseaux sociaux.
    /// </summary>
    public static class SetRecapExportService
    {
        public static RenderTargetBitmap RenderRecapCard(SetRecapStats stats)
        {
            int width = 1080;
            int height = 1350; // Format 4:5 idéal pour Instagram / Stories / Réseaux

            var visual = new DrawingVisual();
            using (var dc = visual.RenderOpen())
            {
                // 1. Fond sombre dégradé moderne style Recall
                var bgGradient = new LinearGradientBrush(
                    Color.FromRgb(15, 18, 24),
                    Color.FromRgb(24, 30, 42),
                    new Point(0, 0),
                    new Point(1, 1)
                );
                dc.DrawRectangle(bgGradient, null, new Rect(0, 0, width, height));

                // 2. Halo lumineux d'accentuation en haut à droite
                var accentColor = DJThemeManager.GetTheme(UserSettings.Shared.DjTheme).AccentColor;
                var glowRadial = new RadialGradientBrush(
                    Color.FromArgb(50, accentColor.R, accentColor.G, accentColor.B),
                    Colors.Transparent
                );
                dc.DrawEllipse(glowRadial, null, new Point(width * 0.85, height * 0.15), 350, 350);

                // Polices
                var fontType = new FontFamily("Segoe UI, Montserrat, sans-serif");
                var culture = CultureInfo.CurrentCulture;

                // 3. Logo & Titre
                var titleText = new FormattedText(
                    "RECALL",
                    culture,
                    FlowDirection.LeftToRight,
                    new Typeface(fontType, FontStyles.Normal, FontWeights.Black, FontStretches.Normal),
                    44,
                    new SolidColorBrush(accentColor),
                    1.25
                );
                dc.DrawText(titleText, new Point(80, 80));

                var subtitleText = new FormattedText(
                    "DJ SET RECAP • BILAN DU MIX",
                    culture,
                    FlowDirection.LeftToRight,
                    new Typeface(fontType, FontStyles.Normal, FontWeights.Bold, FontStretches.Normal),
                    18,
                    new SolidColorBrush(Color.FromRgb(156, 163, 175)),
                    1.25
                );
                dc.DrawText(subtitleText, new Point(80, 140));

                // Date du set
                var dateText = new FormattedText(
                    DateTime.Now.ToString("dddd d MMMM yyyy • HH:mm", culture),
                    culture,
                    FlowDirection.LeftToRight,
                    new Typeface(fontType, FontStyles.Normal, FontWeights.SemiBold, FontStretches.Normal),
                    18,
                    new SolidColorBrush(Color.FromArgb(180, 255, 255, 255)),
                    1.25
                );
                dc.DrawText(dateText, new Point(width - dateText.Width - 80, 95));

                // Ligne séparatrice
                dc.DrawLine(
                    new Pen(new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)), 2),
                    new Point(80, 190),
                    new Point(width - 80, 190)
                );

                // 4. Cartes de Métriques Clés (Durée & Morceaux)
                DrawStatBox(dc, fontType, culture, "DURÉE TOTALE DU SET", FormatDuration(stats.TotalDurationSeconds), 80, 230, 440, 150, accentColor);
                DrawStatBox(dc, fontType, culture, "MORCEAUX ENCHAÎNÉS", $"{stats.TotalTracksCount} TITRES", 560, 230, 440, 150, accentColor);

                // 5. Cadence & BPM
                string avgBpmStr = stats.AverageBpm > 0 ? $"{stats.AverageBpm:F1} BPM" : "--";
                string bpmRangeStr = stats.AverageBpm > 0 ? $"Plage : {(int)stats.MinBpm} - {(int)stats.MaxBpm} BPM" : "";
                DrawStatBox(dc, fontType, culture, "TEMPO MOYEN & PLAGE", avgBpmStr, 80, 410, 440, 150, accentColor, bpmRangeStr);

                string cadenceStr = $"{stats.TracksPerHour:F1} /h";
                string timePerTrackStr = stats.AverageTimePerTrackSeconds > 0 ? $"~{stats.AverageTimePerTrackSeconds / 60.0:F1} min par morceau" : "";
                DrawStatBox(dc, fontType, culture, "CADENCE DE TRANSITION", cadenceStr, 560, 410, 440, 150, accentColor, timePerTrackStr);

                // 6. Harmonie & Tonalité dominante
                string keyStr = !string.IsNullOrEmpty(stats.DominantKey) ? stats.DominantKey : "--";
                string keyDetails = stats.DominantKeyCount > 0 ? $"{stats.DominantKeyCount} morceaux ({(int)Math.Round(stats.DominantKeyPercentage)}% du set)" : "";
                DrawStatBox(dc, fontType, culture, "GAMME & CLÉ DOMINANTE", keyStr, 80, 590, 920, 140, accentColor, keyDetails);

                // 7. Top Genres Musicaux
                DrawListSection(dc, fontType, culture, "TOP GENRES MUSICAUX DU MIX", stats.TopGenres?.Select(g => $"{g.Name} ({g.Count})").Take(4).ToList(), 80, 760, 920, 170, accentColor);

                // 8. Top Artistes Joués
                DrawListSection(dc, fontType, culture, "ARTISTES PHARES DU SET", stats.TopArtists?.Select(a => $"{a.Name} ({a.Count})").Take(4).ToList(), 80, 960, 920, 170, accentColor);

                // 9. Pied de page
                dc.DrawLine(
                    new Pen(new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)), 2),
                    new Point(80, 1190),
                    new Point(width - 80, 1190)
                );

                var footerBrand = new FormattedText(
                    "Généré par Recall • Compagnon DJ Intelligent (revrmusic.github.io/recall)",
                    culture,
                    FlowDirection.LeftToRight,
                    new Typeface(fontType, FontStyles.Normal, FontWeights.Medium, FontStretches.Normal),
                    18,
                    new SolidColorBrush(Color.FromRgb(156, 163, 175)),
                    1.25
                );
                dc.DrawText(footerBrand, new Point(80, 1225));
            }

            var rtb = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
            rtb.Render(visual);
            return rtb;
        }

        private static void DrawStatBox(DrawingContext dc, FontFamily font, CultureInfo culture, string label, string value, double x, double y, double w, double h, Color accent, string? subtitle = null)
        {
            var bgBrush = new SolidColorBrush(Color.FromRgb(28, 33, 44));
            var borderPen = new Pen(new SolidColorBrush(Color.FromArgb(45, 255, 255, 255)), 1.2);
            dc.DrawRoundedRectangle(bgBrush, borderPen, new Rect(x, y, w, h), 12, 12);

            var labelText = new FormattedText(label, culture, FlowDirection.LeftToRight, new Typeface(font, FontStyles.Normal, FontWeights.Bold, FontStretches.Normal), 13, new SolidColorBrush(Color.FromRgb(156, 163, 175)), 1.25);
            dc.DrawText(labelText, new Point(x + 24, y + 20));

            var valText = new FormattedText(value, culture, FlowDirection.LeftToRight, new Typeface(font, FontStyles.Normal, FontWeights.Black, FontStretches.Normal), 32, Brushes.White, 1.25);
            dc.DrawText(valText, new Point(x + 24, y + 52));

            if (!string.IsNullOrEmpty(subtitle))
            {
                var subText = new FormattedText(subtitle, culture, FlowDirection.LeftToRight, new Typeface(font, FontStyles.Normal, FontWeights.SemiBold, FontStretches.Normal), 14, new SolidColorBrush(accent), 1.25);
                dc.DrawText(subText, new Point(x + 24, y + 104));
            }
        }

        private static void DrawListSection(DrawingContext dc, FontFamily font, CultureInfo culture, string header, System.Collections.Generic.List<string>? items, double x, double y, double w, double h, Color accent)
        {
            var bgBrush = new SolidColorBrush(Color.FromRgb(28, 33, 44));
            var borderPen = new Pen(new SolidColorBrush(Color.FromArgb(45, 255, 255, 255)), 1.2);
            dc.DrawRoundedRectangle(bgBrush, borderPen, new Rect(x, y, w, h), 12, 12);

            var headerText = new FormattedText(header, culture, FlowDirection.LeftToRight, new Typeface(font, FontStyles.Normal, FontWeights.Bold, FontStretches.Normal), 14, new SolidColorBrush(accent), 1.25);
            dc.DrawText(headerText, new Point(x + 24, y + 20));

            if (items == null || items.Count == 0)
            {
                var emptyText = new FormattedText("Données insuffisantes pour cette session.", culture, FlowDirection.LeftToRight, new Typeface(font, FontStyles.Normal, FontWeights.Regular, FontStretches.Normal), 14, new SolidColorBrush(Color.FromRgb(156, 163, 175)), 1.25);
                dc.DrawText(emptyText, new Point(x + 24, y + 60));
                return;
            }

            double curX = x + 24;
            double curY = y + 64;

            foreach (var item in items)
            {
                var pillText = new FormattedText(item, culture, FlowDirection.LeftToRight, new Typeface(font, FontStyles.Normal, FontWeights.Bold, FontStretches.Normal), 15, Brushes.White, 1.25);
                double pillW = pillText.Width + 24;
                double pillH = 38;

                if (curX + pillW > x + w - 24)
                {
                    curX = x + 24;
                    curY += 46;
                }

                dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromRgb(38, 45, 60)), null, new Rect(curX, curY, pillW, pillH), 8, 8);
                dc.DrawText(pillText, new Point(curX + 12, curY + 8));

                curX += pillW + 12;
            }
        }

        public static bool SaveToPng(SetRecapStats stats, string targetFilePath)
        {
            try
            {
                var rtb = RenderRecapCard(stats);
                var encoder = new PngBitmapEncoder();
                encoder.Frames.Add(BitmapFrame.Create(rtb));

                using var stream = File.Create(targetFilePath);
                encoder.Save(stream);
                return true;
            }
            catch
            {
                return false;
            }
        }

        public static bool CopyImageToClipboard(SetRecapStats stats)
        {
            try
            {
                var rtb = RenderRecapCard(stats);
                Clipboard.SetImage(rtb);
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static string FormatDuration(double seconds)
        {
            if (seconds <= 0) return "00m 00s";
            var ts = TimeSpan.FromSeconds(seconds);
            if (ts.TotalHours >= 1)
            {
                return $"{(int)ts.TotalHours}h {ts.Minutes:D2}m";
            }
            return $"{ts.Minutes:D2}m {ts.Seconds:D2}s";
        }
    }
}
