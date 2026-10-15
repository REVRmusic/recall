using System;
using System.Text.RegularExpressions;

namespace Recall.Models
{
    public enum HarmonicRelation
    {
        Exact,
        Adjacent,
        Relative,
        EnergyBoost,
        EnergyDrop,
        Incompatible
    }

    public static class HarmonicRelationExtensions
    {
        public static bool IsCompatible(this HarmonicRelation relation) =>
            relation == HarmonicRelation.Exact ||
            relation == HarmonicRelation.Adjacent ||
            relation == HarmonicRelation.Relative ||
            relation == HarmonicRelation.EnergyBoost;

        public static bool IsCompatible(this HarmonicRelation? relation) =>
            relation.HasValue && relation.Value.IsCompatible();

        public static string BadgeText(this HarmonicRelation relation) => relation switch
        {
            HarmonicRelation.Exact => "Identique",
            HarmonicRelation.Adjacent => "Parfait",
            HarmonicRelation.Relative => "Relatif",
            HarmonicRelation.EnergyBoost => "+2 Boost",
            HarmonicRelation.EnergyDrop => "-2 Drop",
            _ => ""
        };

        public static string BadgeText(this HarmonicRelation? relation) =>
            relation.HasValue ? relation.Value.BadgeText() : "";

        public static string Text(this HarmonicRelation? relation) =>
            relation.HasValue ? relation.Value.BadgeText() : "";
    }

    public class CamelotKey : IEquatable<CamelotKey>
    {
        public int Number { get; }
        public string Letter { get; }
        public string MusicalName { get; }

        public CamelotKey(int number, string letter, string musicalName = "")
        {
            Number = Math.Max(1, Math.Min(12, number));
            Letter = letter.Equals("B", StringComparison.OrdinalIgnoreCase) ? "B" : "A";
            MusicalName = !string.IsNullOrEmpty(musicalName) ? musicalName : DefaultMusicalName(Number, Letter);
        }

        public string Code => $"{Number}{Letter}";
        public bool IsMinor => Letter == "A";

        public string DisplayText(int mode = 0) => mode switch
        {
            1 => string.IsNullOrEmpty(MusicalName) ? Code : MusicalName,
            2 => string.IsNullOrEmpty(MusicalName) ? Code : $"{Code} ({MusicalName})",
            _ => Code
        };

        public static CamelotKey? Parse(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;

            string cleaned = raw.Replace("\"", "").Replace("'", "").Trim();

            // 1. Format Camelot direct (ex: "9A", "12B")
            var match = Regex.Match(cleaned, @"^([0-9]{1,2})([ABab])$");
            if (match.Success)
            {
                int num = int.Parse(match.Groups[1].Value);
                string letter = match.Groups[2].Value.ToUpperInvariant();
                return new CamelotKey(num, letter);
            }

            // 2. Format Musical (ex: "Em", "G#m")
            string normalized = cleaned.Replace("♯", "#").Replace("♭", "b").Trim();
            return normalized switch
            {
                // Clés Mineures (A)
                "Abm" or "G#m" or "Sol#m" or "Labm" => new CamelotKey(1, "A", "G#m"),
                "Ebm" or "D#m" or "Re#m" or "Mibm"  => new CamelotKey(2, "A", "Ebm"),
                "Bbm" or "A#m" or "La#m" or "Sibm"  => new CamelotKey(3, "A", "Bbm"),
                "Fm" or "Fam"                       => new CamelotKey(4, "A", "Fm"),
                "Cm" or "Dom"                       => new CamelotKey(5, "A", "Cm"),
                "Gm" or "Solm"                      => new CamelotKey(6, "A", "Gm"),
                "Dm" or "Rem"                       => new CamelotKey(7, "A", "Dm"),
                "Am" or "Lam"                       => new CamelotKey(8, "A", "Am"),
                "Em" or "Mim"                       => new CamelotKey(9, "A", "Em"),
                "Bm" or "Sim"                       => new CamelotKey(10, "A", "Bm"),
                "F#m" or "Gbm" or "Fa#m" or "Solbm" => new CamelotKey(11, "A", "F#m"),
                "C#m" or "Dbm" or "Do#m" or "Rebm"  => new CamelotKey(12, "A", "C#m"),

                // Clés Majeures (B)
                "B" or "Si"                         => new CamelotKey(1, "B", "B"),
                "F#" or "Gb" or "Fa#" or "Solb"     => new CamelotKey(2, "B", "F#"),
                "Db" or "C#" or "Reb" or "Do#"      => new CamelotKey(3, "B", "Db"),
                "Ab" or "G#" or "Lab" or "Sol#"     => new CamelotKey(4, "B", "Ab"),
                "Eb" or "D#" or "Mib" or "Re#"      => new CamelotKey(5, "B", "Eb"),
                "Bb" or "A#" or "Sib" or "La#"      => new CamelotKey(6, "B", "Bb"),
                "F" or "Fa"                         => new CamelotKey(7, "B", "F"),
                "C" or "Do"                         => new CamelotKey(8, "B", "C"),
                "G" or "Sol"                        => new CamelotKey(9, "B", "G"),
                "D" or "Re"                         => new CamelotKey(10, "B", "D"),
                "A" or "La"                         => new CamelotKey(11, "B", "A"),
                "E" or "Mi"                         => new CamelotKey(12, "B", "E"),

                _ => null
            };
        }

        private static string DefaultMusicalName(int number, string letter)
        {
            if (letter == "A")
            {
                return number switch
                {
                    1 => "G#m", 2 => "Ebm", 3 => "Bbm", 4 => "Fm", 5 => "Cm", 6 => "Gm",
                    7 => "Dm", 8 => "Am", 9 => "Em", 10 => "Bm", 11 => "F#m", 12 => "C#m",
                    _ => ""
                };
            }
            return number switch
            {
                1 => "B", 2 => "F#", 3 => "Db", 4 => "Ab", 5 => "Eb", 6 => "Bb",
                7 => "F", 8 => "C", 9 => "G", 10 => "D", 11 => "A", 12 => "E",
                _ => ""
            };
        }

        public HarmonicRelation Relationship(CamelotKey? other)
        {
            if (other is null) return HarmonicRelation.Incompatible;
            if (Equals(other)) return HarmonicRelation.Exact;

            if (Letter == other.Letter)
            {
                int diff = Math.Abs(Number - other.Number);
                if (diff == 1 || diff == 11) return HarmonicRelation.Adjacent;
                if ((Number + 2 - 1) % 12 + 1 == other.Number) return HarmonicRelation.EnergyBoost;
                if ((Number - 2 + 11) % 12 + 1 == other.Number) return HarmonicRelation.EnergyDrop;
            }

            if (Number == other.Number && Letter != other.Letter)
            {
                return HarmonicRelation.Relative;
            }

            return HarmonicRelation.Incompatible;
        }

        public HarmonicRelation GetRelationshipWith(CamelotKey? other) => Relationship(other);

        public string ColorHex => IsMinor switch
        {
            true => Number switch
            {
                1 => "#6EF3E0", 2 => "#8BF3B3", 3 => "#BAF797", 4 => "#F9DE93",
                5 => "#F9C7AD", 6 => "#F8B8BC", 7 => "#F8B5CD", 8 => "#F3B4E6",
                9 => "#E2BCFF", 10 => "#C5D5FF", 11 => "#9BE7FB", 12 => "#6BF4F3",
                _ => "#888888"
            },
            false => Number switch
            {
                1 => "#55ECCC", 2 => "#4FEE81", 3 => "#88F34C", 4 => "#F7CB4B",
                5 => "#F6A47E", 6 => "#F58895", 7 => "#F580B4", 8 => "#EC83DB",
                9 => "#CD8DFF", 10 => "#A0B5FF", 11 => "#5BD7F8", 12 => "#58EBEC",
                _ => "#888888"
            }
        };

        public bool Equals(CamelotKey? other)
        {
            if (other is null) return false;
            return Number == other.Number && Letter == other.Letter;
        }

        public override bool Equals(object? obj) => Equals(obj as CamelotKey);
        public override int GetHashCode() => HashCode.Combine(Number, Letter);
    }
}
