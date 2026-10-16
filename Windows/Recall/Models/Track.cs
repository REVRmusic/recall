using System;
using System.IO;
using System.Text.RegularExpressions;

namespace Recall.Models
{
    public class Track
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public int? AssetId { get; set; }
        public int? HistoryEntryId { get; set; }
        public string Title { get; set; } = "";
        public string Artist { get; set; } = "";
        public double Bpm { get; set; } = 0.0;
        public string RawKey { get; set; } = "";
        public CamelotKey? CamelotKey { get; set; }
        public string? FilePath { get; set; }
        public string FileName { get; set; } = "";
        public string PortableId { get; set; } = "";
        public string? Deck { get; set; }
        public DateTime? PlayedAt { get; set; }

        public int TransitionCount { get; set; } = 0;
        public HarmonicRelation? HarmonicRelation { get; set; }
        public double? BpmDiff { get; set; }
        public bool IsFavorite { get; set; } = false;
        public bool IsPlayedInSession { get; set; } = false;

        private static readonly Regex AudioExtRegex = new(@"\.(mp3|wav|aiff|flac|m4a|aac|ogg|alac)$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
        private static readonly Regex TrackNoPrefixRegex = new(@"^[0-9]{1,3}[A-Za-z]?\s*[\.-]\s+", RegexOptions.Compiled);
        private static readonly Regex SpacedDashRegex = new(@"\s+[-–—]\s+", RegexOptions.Compiled);
        private static readonly Regex TechMarkerRegex = new(@"^(track|side\s*[ab]|cd\s*[0-9]+)$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
        private static readonly Regex GenericVersionRegex = new(@"^(instrumental|acapella|accapella|extended mix|original mix|clean|dirty|radio edit|dub mix|club mix|club edit|remix|edit|bootleg|intro|outro)$", RegexOptions.IgnoreCase | RegexOptions.Compiled);

        public static (string? Artist, string Title) ParseSmartArtistAndTitle(string rawString)
        {
            string raw = rawString.Trim();
            if (string.IsNullOrEmpty(raw)) return (null, "");

            // 1. Supprimer l'extension
            raw = AudioExtRegex.Replace(raw, "");

            // 2. Nettoyer préfixe numéro de piste
            string cleaned = TrackNoPrefixRegex.Replace(raw, "");

            // 3. Détecter séparateur "Artiste - Titre"
            var match = SpacedDashRegex.Match(cleaned);
            if (!match.Success) return (null, raw);

            string artistCand = cleaned.Substring(0, match.Index).Trim();
            string titleCand = cleaned.Substring(match.Index + match.Length).Trim();

            // 4. Validation anti faux-positifs
            if (artistCand.Length < 1 || artistCand.Length > 60 || titleCand.Length < 1) return (null, raw);
            if (Regex.IsMatch(artistCand, @"^[0-9]+$")) return (null, raw);
            if (TechMarkerRegex.IsMatch(artistCand)) return (null, raw);
            if (GenericVersionRegex.IsMatch(titleCand)) return (null, raw);

            return (artistCand, titleCand);
        }

        public (string? Artist, string Title) SmartParsed
        {
            get
            {
                string trimmedArtist = Artist.Trim();
                if (!string.IsNullOrEmpty(trimmedArtist) &&
                    !trimmedArtist.Equals("artiste inconnu", StringComparison.OrdinalIgnoreCase) &&
                    !trimmedArtist.Equals("unknown artist", StringComparison.OrdinalIgnoreCase) &&
                    !trimmedArtist.Equals("unknown", StringComparison.OrdinalIgnoreCase))
                {
                    string directTitle = !string.IsNullOrEmpty(Title.Trim()) ? Title.Trim() :
                        (!string.IsNullOrEmpty(FileName.Trim()) ? Path.GetFileNameWithoutExtension(FileName) : "Morceau inconnu");
                    return (trimmedArtist, directTitle);
                }

                string sourceString = !string.IsNullOrEmpty(Title.Trim()) ? Title :
                    (!string.IsNullOrEmpty(FileName.Trim()) ? Path.GetFileNameWithoutExtension(FileName) : "");

                return ParseSmartArtistAndTitle(sourceString);
            }
        }

        public string DisplayTitle
        {
            get
            {
                var parsed = SmartParsed;
                if (!string.IsNullOrWhiteSpace(parsed.Title)) return parsed.Title;
                if (!string.IsNullOrWhiteSpace(FileName)) return Path.GetFileNameWithoutExtension(FileName);
                return "Morceau inconnu";
            }
        }

        public string DisplayArtist
        {
            get
            {
                var parsed = SmartParsed;
                if (!string.IsNullOrWhiteSpace(parsed.Artist)) return parsed.Artist;
                if (!string.IsNullOrWhiteSpace(Artist)) return Artist;
                return "Artiste inconnu";
            }
        }

        public string FullTooltip
        {
            get
            {
                string t = DisplayTitle;
                string a = DisplayArtist;
                return (!string.IsNullOrEmpty(a) && a != "Artiste inconnu") ? $"{t}\n{a}" : t;
            }
        }

        public string DisplayBpm
        {
            get
            {
                if (Bpm <= 0) return "--";
                if (Math.Abs(Math.Round(Bpm) - Bpm) < 0.05) return $"{(int)Math.Round(Bpm)}";
                return Bpm.ToString("F1");
            }
        }

        public string DisplayKey => CamelotKey?.DisplayText(UserSettings.Shared.KeyDisplayMode) ?? (!string.IsNullOrEmpty(RawKey) ? RawKey : "--");
        public string KeyColorHex => CamelotKey?.ColorHex ?? "#888888";

        public bool IsFileAvailable => !string.IsNullOrEmpty(FilePath) && File.Exists(FilePath);

        public static string ExtractBaseTitle(string fullTitle)
        {
            if (string.IsNullOrWhiteSpace(fullTitle)) return "";
            string cleaned = fullTitle.Trim();
            cleaned = Regex.Replace(cleaned, @"\s*\([^)]*\)", "");
            cleaned = Regex.Replace(cleaned, @"\s*\[[^\]]*\]", "");
            cleaned = Regex.Replace(cleaned, @"\s*\{[^}]*\}", "");
            cleaned = Regex.Replace(cleaned, @"\s+(feat\.|ft\.|featuring|with|vs\.|pres\.).*$", "", RegexOptions.IgnoreCase);
            cleaned = Regex.Replace(cleaned, @"\s+[-–—]\s+.*(remix|edit|mix|version|vip|dub|bootleg|rework|flip|extended|club|radio|intro|outro|clean|dirty|short|acapella|instrumental|mashup|refix|cut).*$", "", RegexOptions.IgnoreCase);
            cleaned = cleaned.Trim();
            return string.IsNullOrEmpty(cleaned) ? fullTitle : cleaned;
        }
    }
}
