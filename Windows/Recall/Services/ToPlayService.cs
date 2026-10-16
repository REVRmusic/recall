using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Recall.Models;

namespace Recall.Services
{
    public class ToPlayTrackData
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string Title { get; set; } = "";
        public string Artist { get; set; } = "";
        public double Bpm { get; set; }
        public string RawKey { get; set; } = "";
        public string? FilePath { get; set; }
        public string FileName { get; set; } = "";
        public string PortableId { get; set; } = "";
        public DateTime AddedAt { get; set; } = DateTime.UtcNow;

        public ToPlayTrackData() { }

        public ToPlayTrackData(Track track)
        {
            Id = Guid.NewGuid().ToString();
            Title = track.Title;
            Artist = track.Artist;
            Bpm = track.Bpm;
            RawKey = track.RawKey;
            FilePath = track.FilePath;
            FileName = track.FileName;
            PortableId = track.PortableId;
            AddedAt = DateTime.UtcNow;
        }

        public Track ToTrack(Track? referenceTrack = null)
        {
            var t = new Track
            {
                Id = Id,
                Title = Title,
                Artist = Artist,
                Bpm = Bpm,
                RawKey = RawKey,
                CamelotKey = CamelotKey.Parse(RawKey),
                FilePath = FilePath,
                FileName = FileName,
                PortableId = PortableId
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

    public class ToPlayService
    {
        private static ToPlayService? _shared;
        public static ToPlayService Shared => _shared ??= new ToPlayService();

        private List<ToPlayTrackData> _tracks = new();

        private static string FilePath
        {
            get
            {
                string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                string folder = Path.Combine(appData, "Recall");
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
                return Path.Combine(folder, "to_play_tracks.json");
            }
        }

        public ToPlayService()
        {
            LoadTracks();
        }

        public void LoadTracks()
        {
            try
            {
                if (File.Exists(FilePath))
                {
                    string json = File.ReadAllText(FilePath);
                    _tracks = JsonSerializer.Deserialize<List<ToPlayTrackData>>(json) ?? new();
                }
            }
            catch
            {
                _tracks = new();
            }
        }

        public void SaveTracks()
        {
            try
            {
                string json = JsonSerializer.Serialize(_tracks, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(FilePath, json);
            }
            catch { }
        }

        public List<ToPlayTrackData> GetTracks() => _tracks;

        public bool AddTrack(Track track)
        {
            string normTitle = Normalize(track.DisplayTitle);
            int existingIndex = _tracks.FindIndex(t => Normalize(t.Title) == normTitle ||
                (!string.IsNullOrEmpty(track.FileName) && !string.IsNullOrEmpty(t.FileName) && Normalize(t.FileName) == Normalize(track.FileName)));

            if (existingIndex >= 0)
            {
                var existing = _tracks[existingIndex];
                _tracks.RemoveAt(existingIndex);
                _tracks.Insert(0, existing);
                SaveTracks();
                return true;
            }

            _tracks.Insert(0, new ToPlayTrackData(track));
            SaveTracks();
            return true;
        }

        public bool AddTrackFromPath(string path)
        {
            if (!File.Exists(path)) return false;

            string fileName = Path.GetFileName(path);
            var serato = new SeratoDatabaseService(UserSettings.Shared.EffectiveDatabasePath);
            var seratoTrack = serato.FindTrackByFile(path, fileName);
            if (seratoTrack != null)
            {
                return AddTrack(seratoTrack);
            }

            var rbTrack = RekordboxService.Shared.FindTrackByFile(path, fileName);
            if (rbTrack != null)
            {
                return AddTrack(rbTrack);
            }

            // Fallback nom de fichier
            string titleWithoutExt = Path.GetFileNameWithoutExtension(path);
            var fallback = new Track
            {
                Title = titleWithoutExt,
                Artist = "",
                FilePath = path,
                FileName = fileName,
                PortableId = path
            };

            return AddTrack(fallback);
        }

        public void RemoveTrack(string id)
        {
            _tracks.RemoveAll(t => t.Id == id);
            SaveTracks();
        }

        public void ClearAll()
        {
            _tracks.Clear();
            SaveTracks();
        }

        public List<Track> ToTrackList(Track? referenceTrack = null)
        {
            var list = _tracks.Select(t => t.ToTrack(referenceTrack)).ToList();
            if (referenceTrack == null || (referenceTrack.Bpm <= 0 && referenceTrack.CamelotKey == null))
            {
                return list;
            }
            return SortTracksByMatch(list, referenceTrack);
        }

        private List<Track> SortTracksByMatch(List<Track> tracks, Track referenceTrack)
        {
            var indexed = tracks.Select((t, idx) => (track: t, index: idx, score: CalculateMatchScore(t, referenceTrack))).ToList();

            return indexed.OrderBy(x => x.score)
                          .ThenBy(x => x.index)
                          .Select(x => x.track)
                          .ToList();
        }

        private double CalculateMatchScore(Track track, Track reference)
        {
            // 1. Écart de BPM (facteur prépondérant)
            double bpmPenalty;
            if (reference.Bpm > 0 && track.Bpm > 0)
            {
                double bRef = reference.Bpm;
                double bCand = track.Bpm;

                double diffDirect = Math.Abs(bCand - bRef) / bRef;
                double diffHalf = Math.Abs((bCand * 2.0) - bRef) / bRef + 0.04;
                double diffDouble = Math.Abs((bCand / 2.0) - bRef) / bRef + 0.04;

                bpmPenalty = Math.Min(diffDirect, Math.Min(diffHalf, diffDouble));
            }
            else
            {
                bpmPenalty = 0.50;
            }

            // 2. Compatibilité Harmonique (gamme, paramètre secondaire)
            double harmonicBonus = 0.0;
            if (track.HarmonicRelation.HasValue)
            {
                switch (track.HarmonicRelation.Value)
                {
                    case HarmonicRelation.Exact:
                        harmonicBonus = 0.025;
                        break;
                    case HarmonicRelation.Adjacent:
                        harmonicBonus = 0.020;
                        break;
                    case HarmonicRelation.Relative:
                        harmonicBonus = 0.018;
                        break;
                    case HarmonicRelation.EnergyBoost:
                        harmonicBonus = 0.012;
                        break;
                    case HarmonicRelation.EnergyDrop:
                        harmonicBonus = 0.006;
                        break;
                }
            }

            double favoriteBonus = track.IsFavorite ? 0.005 : 0.0;

            return bpmPenalty - harmonicBonus - favoriteBonus;
        }

        public static string Normalize(string str)
        {
            if (string.IsNullOrWhiteSpace(str)) return "";
            return new string(str.ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());
        }
    }
}
