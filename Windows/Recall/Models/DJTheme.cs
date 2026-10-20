using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Media;

namespace Recall.Models
{
    public class DJThemeItem
    {
        public string Id { get; set; } = "cyanNeon";
        public string Name { get; set; } = "Cyan Neon";
        public string Subtitle { get; set; } = "Signature Recall • Cyber Cyan";
        public string AccentHex { get; set; } = "#00D9E6";
        public string SecondaryHex { get; set; } = "#3399FF";
        public Color AccentColor => (Color)ColorConverter.ConvertFromString(AccentHex);
        public Color SecondaryColor => (Color)ColorConverter.ConvertFromString(SecondaryHex);
        public SolidColorBrush AccentBrush => new(AccentColor);
        public SolidColorBrush SecondaryBrush => new(SecondaryColor);
    }

    public static class DJThemeManager
    {
        public static readonly List<DJThemeItem> AvailableThemes = new()
        {
            new DJThemeItem
            {
                Id = "cyanNeon",
                Name = "Cyan Neon",
                Subtitle = "Signature Recall • Cyber Cyan",
                AccentHex = "#00D9E6",
                SecondaryHex = "#3399FF"
            },
            new DJThemeItem
            {
                Id = "electricPurple",
                Name = "Electric Purple",
                Subtitle = "Vibe Nocturne • Violet Laser & Deep",
                AccentHex = "#B859FF",
                SecondaryHex = "#EB47CC"
            },
            new DJThemeItem
            {
                Id = "sunsetAmber",
                Name = "Sunset Amber",
                Subtitle = "Chaleur Analogique • Or & Ambre",
                AccentHex = "#FF9E14",
                SecondaryHex = "#FF592E"
            },
            new DJThemeItem
            {
                Id = "acidGreen",
                Name = "Acid Green",
                Subtitle = "Énergie Club • Vert Acide & Rave",
                AccentHex = "#38EB61",
                SecondaryHex = "#0DD9CC"
            }
        };

        public static DJThemeItem GetTheme(string? themeId)
        {
            if (string.IsNullOrWhiteSpace(themeId)) return AvailableThemes[0];
            return AvailableThemes.Find(t => t.Id.Equals(themeId, StringComparison.OrdinalIgnoreCase)) ?? AvailableThemes[0];
        }

        public static void ApplyTheme(string? themeId)
        {
            var theme = GetTheme(themeId);
            if (Application.Current == null) return;

            Application.Current.Dispatcher.Invoke(() =>
            {
                var res = Application.Current.Resources;
                var accentColor = theme.AccentColor;
                var secondaryColor = theme.SecondaryColor;

                res["AccentColor"] = accentColor;
                res["AccentBrush"] = new SolidColorBrush(accentColor);
                res["AccentSecondaryColor"] = secondaryColor;
                res["AccentSecondaryBrush"] = new SolidColorBrush(secondaryColor);

                // Brushes pour surbrillance et contours
                var semiTransparentAccent = Color.FromArgb(40, accentColor.R, accentColor.G, accentColor.B);
                res["AccentPillBgBrush"] = new SolidColorBrush(semiTransparentAccent);

                var glowAccent = Color.FromArgb(90, accentColor.R, accentColor.G, accentColor.B);
                res["AccentGlowBrush"] = new SolidColorBrush(glowAccent);
            });
        }
    }
}
