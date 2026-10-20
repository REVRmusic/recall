using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace Recall.Models
{
    /// <summary>
    /// Utilitaire haute performance de nettoyage et de résolution intelligente des métadonnées des morceaux.
    /// Détecte et élimine les tags promotionnels, handles de réseaux sociaux (Instagram, SoundCloud, etc.),
    /// les tags de record pools (BPM Supreme, DJcity, Club Killers...), et extrait le véritable artiste.
    /// </summary>
    public static class TrackMetadataCleaner
    {
        // Ensemble des genres musicaux génériques connus pour la détection O(1)
        public static readonly HashSet<string> GenericGenres = new(StringComparer.OrdinalIgnoreCase)
        {
            "house", "tech house", "deep house", "afro house", "melodic house", "electro house",
            "progressive house", "bass house", "future house", "tropical house", "acid house",
            "funky house", "soulful house", "jackin house", "g-house", "slap house", "piano house",
            "vocal house", "techno", "peak time", "melodic techno", "hard techno", "minimal",
            "minimal techno", "industrial techno", "acid techno", "detroit techno", "berlin techno",
            "hip hop", "hip-hop", "rap", "trap", "drill", "uk drill", "ny drill", "boom bap",
            "french rap", "rap francais", "rap us", "us rap", "r&b", "rnb", "soul", "neo soul",
            "funk", "disco", "nu disco", "nu-disco", "boogie", "pop", "dance", "electro pop",
            "synth pop", "indie", "indie pop", "indie dance", "rock", "hard rock", "alternative",
            "metal", "punk", "acoustic", "afro", "afrobeats", "afrobeat", "amapiano", "coupe decale",
            "ndombolo", "highlife", "kizomba", "zouk", "kompa", "shatta", "bouyon",
            "latin", "reggaeton", "dancehall", "reggae", "moombahton", "dembow", "bachata",
            "salsa", "merengue", "baile funk", "cumbia", "electronic", "electro", "edm", "trance",
            "psytrance", "dubstep", "drum & bass", "drum and bass", "dnb", "jungle", "uk garage",
            "ukg", "2-step", "bassline", "breakbeat", "breaks", "hardstyle", "hardcore", "ambient",
            "chillout", "lounge", "downtempo", "lo-fi", "lofi", "jazz", "blues", "classical",
            "soundtrack", "world", "folk", "country", "gospel", "general", "other", "autre",
            "divers", "inconnu", "unknown", "club", "dj tools", "acapella", "instrumental",
            "intro", "outro", "transition", "scratch", "sfx", "mashup", "bootleg", "edit", "remix"
        };

        // Regex compilées pour haute cadence d'exécution
        private static readonly Regex AudioExtRegex = new(@"\.(mp3|wav|aiff|flac|m4a|aac|ogg|alac)$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
        private static readonly Regex TrackNoPrefixRegex = new(@"^([0-9]{1,3}[A-Za-z]?[\.-]\s*|[0-9]{1,3}\s+-\s+|[0-9]{1,3}_)", RegexOptions.Compiled);
        private static readonly Regex MultiSeparatorRegex = new(@"(\s+[-–—]\s+|\s+\/\/\s+|\s+\|\s+|\s+_\s+)", RegexOptions.Compiled);
        private static readonly Regex SocialPrefixRegex = new(@"(?i)^(@[a-zA-Z0-9_\.]+|insta(gram)?\s*[:@-]|ig\s*[:@-]|tiktok\s*[:@-]|soundcloud\s*[:@-]|sc\s*[:@-]|fb\s*[:@-]|facebook\s*[:@-]|yt\s*[:@-]|youtube\s*[:@-]|twitter\s*[:@-]|telegram\s*[:@-]|t\.me\/).*", RegexOptions.Compiled);
        private static readonly Regex WebDomainRegex = new(@"(?i)(https?:\/\/|www\.|\b[a-z0-9_-]+\.(com|fr|net|org|io|co|me|club|dj|top|info|xyz|app|de|uk|ru|eu|es|it)\b)", RegexOptions.Compiled);
        private static readonly Regex PromoPoolKeywordsRegex = new(@"(?i)\b(free\s*(dl|download)|edit(s)?\s*pack|bootleg(s)?\s*pack|mashup(s)?\s*pack|dj\s*pool|record\s*pool|promo\s*only|promo\s*copy|exclusive\s*(promo|edit|bootleg)|bpm\s*supreme|dj\s*city|club\s*killers|heavy\s*hits|franchise\s*pool|direct\s*music\s*service|zipdj|barbangerz|crooklyn\s*clan|crack4dj|idjpool|hypeddit|toneden)\b", RegexOptions.Compiled);
        private static readonly Regex PlaceholderRegex = new(@"^(?i)(unknown(\s+artist)?|artiste\s+inconnu|artiste|artist|various(\s+artists)?|divers(\s+artistes)?|compilation|v\.?a\.?|v\/a|track|piste|audio|untitled|sans\s+titre|none|n\/?a|null|nil|undefined|\?+|-+|\.+|_)$", RegexOptions.Compiled);
        private static readonly Regex NumericOrSpecRegex = new(@"^(?i)([0-9]+(\s*kbps)?|320\s*kbps|128\s*kbps|wav|mp3|flac|aiff|aac|m4a|lossless)$", RegexOptions.Compiled);
        private static readonly Regex TechMarkerRegex = new(@"^(track|side\s*[ab]|cd\s*[0-9]+)$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
        private static readonly Regex GenericVersionRegex = new(@"^(instrumental|acapella|accapella|extended mix|original mix|clean|dirty|radio edit|dub mix|club mix|club edit|remix|edit|bootleg|intro|outro)$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
        private static readonly Regex TrailingPromoInArtistRegex = new(@"\s*[\[\(](?i)(insta(gram)?|ig|soundcloud|tiktok|free\s*dl|download|edit|remix|bootleg|pack|www\.).*?[\]\)]", RegexOptions.Compiled);
        private static readonly Regex MultiSpaceRegex = new(@"\s{2,}", RegexOptions.Compiled);

        public struct CleanedResult
        {
            public string Title;
            public string? Artist;
            public string RawCleanedTitle;
            public bool ExtractedFromFileName;
        }

        public static CleanedResult Clean(string rawTitle, string? rawArtist, string? fileName = null, string? genre = null)
        {
            string cleanTitle = (rawTitle ?? "").Trim();
            string cleanArtist = (rawArtist ?? "").Trim();
            string cleanFn = (fileName ?? "").Trim();
            string cleanGenre = (genre ?? "").Trim();

            // 1. Nettoyage de l'artiste si c'est un placeholder
            if (IsPlaceholder(cleanArtist) || IsPromoString(cleanArtist))
            {
                cleanArtist = "";
            }

            // 2. Si l'artiste est vide, tenter de l'extraire du titre ou du nom de fichier
            bool extractedFromFn = false;
            if (string.IsNullOrEmpty(cleanArtist))
            {
                var fromTitle = ExtractArtistAndTitle(cleanTitle);
                if (!string.IsNullOrEmpty(fromTitle.Artist))
                {
                    cleanArtist = fromTitle.Artist;
                    cleanTitle = fromTitle.Title;
                }
                else if (!string.IsNullOrEmpty(cleanFn))
                {
                    var fromFn = ExtractArtistAndTitle(cleanFn);
                    if (!string.IsNullOrEmpty(fromFn.Artist))
                    {
                        cleanArtist = fromFn.Artist;
                        if (string.IsNullOrEmpty(cleanTitle) || IsPlaceholder(cleanTitle))
                        {
                            cleanTitle = fromFn.Title;
                        }
                        extractedFromFn = true;
                    }
                }
            }

            // 3. Si toujours pas d'artiste mais que le champ genre contient un véritable nom d'artiste
            if (string.IsNullOrEmpty(cleanArtist) && !string.IsNullOrEmpty(cleanGenre) && !GenericGenres.Contains(cleanGenre))
            {
                if (!IsPlaceholder(cleanGenre) && !IsPromoString(cleanGenre) && cleanGenre.Length >= 2 && cleanGenre.Length <= 40)
                {
                    cleanArtist = cleanGenre;
                }
            }

            // 4. Nettoyage final du titre (élimination des tags de promo résiduels)
            cleanTitle = Scrubber(cleanTitle);
            if (!string.IsNullOrEmpty(cleanArtist))
            {
                cleanArtist = Scrubber(cleanArtist);
            }

            return new CleanedResult
            {
                Title = !string.IsNullOrWhiteSpace(cleanTitle) ? cleanTitle : (!string.IsNullOrWhiteSpace(cleanFn) ? AudioExtRegex.Replace(cleanFn, "") : "Morceau inconnu"),
                Artist = !string.IsNullOrWhiteSpace(cleanArtist) ? cleanArtist : null,
                RawCleanedTitle = cleanTitle,
                ExtractedFromFileName = extractedFromFn
            };
        }

        public static bool IsPlaceholder(string str)
        {
            if (string.IsNullOrWhiteSpace(str)) return true;
            string s = str.Trim();
            if (PlaceholderRegex.IsMatch(s)) return true;
            if (NumericOrSpecRegex.IsMatch(s)) return true;
            if (TechMarkerRegex.IsMatch(s)) return true;
            return false;
        }

        public static bool IsPromoString(string str)
        {
            if (string.IsNullOrWhiteSpace(str)) return false;
            string s = str.Trim();
            if (SocialPrefixRegex.IsMatch(s)) return true;
            if (WebDomainRegex.IsMatch(s)) return true;
            if (PromoPoolKeywordsRegex.IsMatch(s)) return true;
            return false;
        }

        public static (string? Artist, string Title) ExtractArtistAndTitle(string rawSource)
        {
            if (string.IsNullOrWhiteSpace(rawSource)) return (null, "");

            string s = AudioExtRegex.Replace(rawSource.Trim(), "");
            s = TrackNoPrefixRegex.Replace(s, "").Trim();

            var match = MultiSeparatorRegex.Match(s);
            if (!match.Success) return (null, s);

            string candArtist = s.Substring(0, match.Index).Trim();
            string candTitle = s.Substring(match.Index + match.Length).Trim();

            if (candArtist.Length < 1 || candArtist.Length > 65 || candTitle.Length < 1) return (null, s);
            if (IsPlaceholder(candArtist)) return (null, s);
            if (GenericVersionRegex.IsMatch(candTitle)) return (null, s);

            return (candArtist, candTitle);
        }

        private static string Scrubber(string input)
        {
            if (string.IsNullOrWhiteSpace(input)) return "";
            string s = input;

            // Retirer extensions audio si présentes
            s = AudioExtRegex.Replace(s, "");

            // Retirer tags de réseaux sociaux entre parenthèses ou crochets
            s = TrailingPromoInArtistRegex.Replace(s, "");

            // Supprimer les espaces multiples
            s = MultiSpaceRegex.Replace(s, " ").Trim();

            return s;
        }
    }
}
