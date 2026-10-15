using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Recall.Models;

namespace Recall.Services
{
    public class SavedTrackData
    {
        public string Title { get; set; } = "";
        public string Artist { get; set; } = "";
        public double Bpm { get; set; }
        public string RawKey { get; set; } = "";
        public string? FilePath { get; set; }
        public string FileName { get; set; } = "";
        public string PortableId { get; set; } = "";

        public SavedTrackData() { }

        public SavedTrackData(Track track)
        {
            Title = track.Title;
            Artist = track.Artist;
            Bpm = track.Bpm;
            RawKey = track.RawKey;
            FilePath = track.FilePath;
            FileName = track.FileName;
            PortableId = track.PortableId;
        }

        public Track ToTrack(Track? referenceTrack = null)
        {
            var t = new Track
            {
                Title = Title,
                Artist = Artist,
                Bpm = Bpm,
                RawKey = RawKey,
                CamelotKey = CamelotKey.Parse(RawKey),
                FilePath = FilePath,
                FileName = FileName,
                PortableId = PortableId,
                IsFavorite = true
            };

            if (referenceTrack?.CamelotKey != null && t.CamelotKey != null)
            {
                t.HarmonicRelation = referenceTrack.CamelotKey.Relationship(t.CamelotKey);
            }

            if (referenceTrack != null && referenceTrack.Bpm > 0 && t.Bpm > 0)
            {
                t.BpmDiff = t.Bpm - referenceTrack.Bpm;
            }

            return t;
        }
    }

    public class SavedCombo
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public SavedTrackData Track1 { get; set; } = new();
        public SavedTrackData Track2 { get; set; } = new();
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public class FavoriteCombosService
    {
        private static FavoriteCombosService? _shared;
        public static FavoriteCombosService Shared => _shared ??= new FavoriteCombosService();

        private List<SavedCombo> _combos = new();

        private static string FilePath
        {
            get
            {
                string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string folder = Path.Combine(appData, "Recall");
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
                return Path.Combine(folder, "recall_favorite_combos.json");
            }
        }

        public FavoriteCombosService()
        {
            LoadCombos();
        }

        public void LoadCombos()
        {
            try
            {
                if (File.Exists(FilePath))
                {
                    string json = File.ReadAllText(FilePath);
                    _combos = JsonSerializer.Deserialize<List<SavedCombo>>(json) ?? new();
                }
            }
            catch
            {
                _combos = new();
            }
        }

        public void SaveCombos()
        {
            try
            {
                string json = JsonSerializer.Serialize(_combos, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(FilePath, json);
            }
            catch { }
        }

        public static string Normalize(string text) =>
            new string(text.Where(char.IsLetterOrDigit).ToArray()).ToLowerInvariant();

        public bool IsComboFavorite(Track t1, Track t2)
        {
            string n1 = Normalize(t1.DisplayTitle);
            string n2 = Normalize(t2.DisplayTitle);
            if (string.IsNullOrEmpty(n1) || string.IsNullOrEmpty(n2)) return false;

            return _combos.Any(c =>
            {
                string c1 = Normalize(c.Track1.Title);
                string c2 = Normalize(c.Track2.Title);
                return (c1 == n1 && c2 == n2) || (c1 == n2 && c2 == n1);
            });
        }

        public void ToggleCombo(Track t1, Track t2)
        {
            string n1 = Normalize(t1.DisplayTitle);
            string n2 = Normalize(t2.DisplayTitle);

            var existing = _combos.FirstOrDefault(c =>
            {
                string c1 = Normalize(c.Track1.Title);
                string c2 = Normalize(c.Track2.Title);
                return (c1 == n1 && c2 == n2) || (c1 == n2 && c2 == n1);
            });

            if (existing != null)
            {
                _combos.Remove(existing);
            }
            else
            {
                _combos.Add(new SavedCombo
                {
                    Track1 = new SavedTrackData(t1),
                    Track2 = new SavedTrackData(t2)
                });
            }

            SaveCombos();
        }

        public List<Track> GetFavoriteSuggestionsFor(Track currentTrack)
        {
            var result = new List<Track>();
            string currNorm = Normalize(currentTrack.DisplayTitle);
            if (string.IsNullOrEmpty(currNorm)) return result;

            foreach (var combo in _combos)
            {
                string c1 = Normalize(combo.Track1.Title);
                string c2 = Normalize(combo.Track2.Title);

                if (c1 == currNorm)
                {
                    result.Add(combo.Track2.ToTrack(currentTrack));
                }
                else if (c2 == currNorm)
                {
                    result.Add(combo.Track1.ToTrack(currentTrack));
                }
            }

            return result;
        }
    }
}
