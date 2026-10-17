using System;
using System.IO;
using System.Text.Json;

namespace Recall.Models
{
    public class UserSettings
    {
        private static UserSettings? _shared;
        public static UserSettings Shared => _shared ??= Load();

        public string DjSoftwareMode { get; set; } = "auto"; // "auto", "serato", "rekordbox"
        public string TransitionDirection { get; set; } = "next"; // "next", "previous", "all"
        public string RekordboxXmlCustomPath { get; set; } = "";
        public int HistoryDaysLookback { get; set; } = 360;
        public int MaxSuggestions { get; set; } = 30;
        public double BpmTolerancePercent { get; set; } = 8.0;
        public bool IsBpmFilterActive { get; set; } = false;
        public bool IsHarmonicFilterActive { get; set; } = false;
        public bool IsFavoritesFilterActive { get; set; } = false;
        public bool IsToPlayFilterActive { get; set; } = false;
        public int MinTransitionsCount { get; set; } = 1;
        public bool AlwaysOnTop { get; set; } = true;
        public bool IsCompactMode { get; set; } = false;
        public bool HidePlayedTracks { get; set; } = false;
        public string SeratoDatabaseCustomPath { get; set; } = "";
        public string PlayedTrackColorHex { get; set; } = "#0FA2FF";
        public string PlayedTrackStyle { get; set; } = "both"; // "both", "textOnly", "bgOnly"
        public int PlayedMinDurationSeconds { get; set; } = 25;
        public int KeyDisplayMode { get; set; } = 0; // 0: Camelot (9A), 1: Musicale (Em), 2: Combiné
        public bool CumulateVariantSuggestions { get; set; } = true;

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

        public static string? AutoDetectRekordboxXmlPath()
        {
            try
            {
                string docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
                string candidate1 = Path.Combine(docs, "rekordbox.xml");
                if (File.Exists(candidate1)) return candidate1;

                string candidate2 = Path.Combine(docs, "Lexicon", "rekordbox.xml");
                if (File.Exists(candidate2)) return candidate2;

                string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string candidate3 = Path.Combine(appData, "Pioneer", "rekordbox", "rekordbox.xml");
                if (File.Exists(candidate3)) return candidate3;

                // Settings file
                string settingsPath = Path.Combine(appData, "Pioneer", "rekordbox6", "rekordbox3.settings");
                if (File.Exists(settingsPath))
                {
                    string content = File.ReadAllText(settingsPath);
                    var match = System.Text.RegularExpressions.Regex.Match(content, "name=\"bridgeImportedLibraryFile\"\\s+val=\"([^\"]+)\"");
                    if (match.Success)
                    {
                        string candidate = match.Groups[1].Value;
                        if (File.Exists(candidate)) return candidate;
                    }
                }
            }
            catch { }

            return null;
        }

        public string EffectiveRekordboxXmlPath
        {
            get
            {
                if (!string.IsNullOrWhiteSpace(RekordboxXmlCustomPath) && File.Exists(RekordboxXmlCustomPath.Trim()))
                {
                    return RekordboxXmlCustomPath.Trim();
                }
                string? auto = AutoDetectRekordboxXmlPath();
                if (!string.IsNullOrWhiteSpace(auto)) return auto;

                return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "rekordbox.xml");
            }
        }

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
