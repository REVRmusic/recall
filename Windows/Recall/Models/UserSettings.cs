using System;
using System.IO;
using System.Text.Json;

namespace Recall.Models
{
    public class UserSettings
    {
        private static UserSettings? _shared;
        public static UserSettings Shared => _shared ??= Load();

        public int HistoryDaysLookback { get; set; } = 360;
        public int MaxSuggestions { get; set; } = 30;
        public double BpmTolerancePercent { get; set; } = 8.0;
        public bool IsBpmFilterActive { get; set; } = false;
        public bool IsHarmonicFilterActive { get; set; } = false;
        public bool IsFavoritesFilterActive { get; set; } = false;
        public int MinTransitionsCount { get; set; } = 1;
        public bool AlwaysOnTop { get; set; } = true;
        public bool IsCompactMode { get; set; } = false;
        public bool HidePlayedTracks { get; set; } = false;
        public string SeratoDatabaseCustomPath { get; set; } = "";
        public string PlayedTrackColorHex { get; set; } = "#0FA2FF";
        public string PlayedTrackStyle { get; set; } = "both"; // "both", "textOnly", "bgOnly"
        public int PlayedMinDurationSeconds { get; set; } = 25;

        private static string SettingsFilePath
        {
            get
            {
                string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string folder = Path.Combine(appData, "Recall");
                if (!Directory.Exists(folder))
                {
                    Directory.CreateDirectory(folder);
                }
                return Path.Combine(folder, "settings.json");
            }
        }

        public string DefaultDatabasePath
        {
            get
            {
                // Emplacement officiel Serato DJ Pro sous Windows
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string primary = Path.Combine(localAppData, "Serato", "Library", "master.sqlite");
                if (File.Exists(primary)) return primary;

                // Emplacement secondaire / dossier Musique
                string music = Environment.GetFolderPath(Environment.SpecialFolder.MyMusic);
                string secondary = Path.Combine(music, "_Serato_", "master.sqlite");
                if (File.Exists(secondary)) return secondary;

                return primary;
            }
        }

        public string EffectiveDatabasePath =>
            !string.IsNullOrWhiteSpace(SeratoDatabaseCustomPath) ? SeratoDatabaseCustomPath.Trim() : DefaultDatabasePath;

        public static UserSettings Load()
        {
            try
            {
                string path = SettingsFilePath;
                if (File.Exists(path))
                {
                    string json = File.ReadAllText(path);
                    var settings = JsonSerializer.Deserialize<UserSettings>(json);
                    if (settings != null) return settings;
                }
            }
            catch { }

            return new UserSettings();
        }

        public void Save()
        {
            try
            {
                string path = SettingsFilePath;
                string json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(path, json);
            }
            catch { }
        }
    }
}
