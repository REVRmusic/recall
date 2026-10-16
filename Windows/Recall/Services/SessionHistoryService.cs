using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using Recall.Models;

namespace Recall.Services
{
    public class SessionPlayedTrack
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string Title { get; set; } = "";
        public string Artist { get; set; } = "";
        public string FileName { get; set; } = "";
        public DateTime PlayedAt { get; set; } = DateTime.Now;
        public double DurationSeconds { get; set; } = 0.0;
        public int PlayCount { get; set; } = 1;
        public double Bpm { get; set; } = 0.0;
        public string RawKey { get; set; } = "";
        public string Genre { get; set; } = "";

        public CamelotKey? CamelotKey => CamelotKey.Parse(RawKey);

        public string DisplayTitle
        {
            get
            {
                var parsed = Track.ParseSmartArtistAndTitle(!string.IsNullOrEmpty(Title) ? Title : (!string.IsNullOrEmpty(FileName) ? Path.GetFileNameWithoutExtension(FileName) : "Morceau inconnu"));
                if (!string.IsNullOrWhiteSpace(parsed.Title)) return parsed.Title;
                if (!string.IsNullOrWhiteSpace(FileName)) return Path.GetFileNameWithoutExtension(FileName);
                return !string.IsNullOrEmpty(Title) ? Title : "Morceau inconnu";
            }
        }

        public string DisplayArtist
        {
            get
            {
                if (!string.IsNullOrWhiteSpace(Artist) && !Artist.Equals("artiste inconnu", StringComparison.OrdinalIgnoreCase) && !Artist.Equals("unknown", StringComparison.OrdinalIgnoreCase))
                {
                    return Artist.Trim();
                }
                var parsed = Track.ParseSmartArtistAndTitle(!string.IsNullOrEmpty(Title) ? Title : (!string.IsNullOrEmpty(FileName) ? Path.GetFileNameWithoutExtension(FileName) : ""));
                return parsed.Artist ?? "";
            }
        }

        public string DisplayBpm => Bpm > 0 ? (Math.Abs(Math.Round(Bpm) - Bpm) < 0.05 ? $"{(int)Math.Round(Bpm)}" : Bpm.ToString("F1")) : "--";
        public string DisplayKey => CamelotKey?.DisplayText(UserSettings.Shared.KeyDisplayMode) ?? (!string.IsNullOrEmpty(RawKey) ? RawKey : "--");
    }

    public class SetRecapStats
    {
        public int TotalTracksCount { get; set; }
        public int TotalPlaysCount { get; set; }
        public double TotalDurationSeconds { get; set; }
        public double AverageTimePerTrackSeconds { get; set; }
        public double TracksPerHour { get; set; }

        public double AverageBpm { get; set; }
        public double MinBpm { get; set; }
        public double MaxBpm { get; set; }

        public string? DominantKey { get; set; }
        public int DominantKeyCount { get; set; }
        public double DominantKeyPercentage { get; set; }
        public List<(string Key, int Count, double Percent)> KeyDistribution { get; set; } = new();

        public class TransitionRecord
        {
            public string FromTrack { get; set; } = "";
            public string ToTrack { get; set; } = "";
            public double ElapsedSeconds { get; set; }
        }

        public TransitionRecord? FastestTransition { get; set; }
        public TransitionRecord? LongestTransition { get; set; }

        public class RankedRecord
        {
            public string Name { get; set; } = "";
            public int Count { get; set; }
            public double Percent { get; set; }
        }

        public List<RankedRecord> TopArtists { get; set; } = new();
        public RankedRecord? MostPlayedArtist => TopArtists.FirstOrDefault();

        public List<RankedRecord> TopGenres { get; set; } = new();
        public RankedRecord? MostPlayedGenre => TopGenres.FirstOrDefault();

        public bool IsLiveSession { get; set; }

        public static SetRecapStats Compute(List<SessionPlayedTrack> tracks, DateTime sessionStartTime)
        {
            int count = tracks.Count;
            if (count == 0)
            {
                return new SetRecapStats
                {
                    TotalTracksCount = 0,
                    TotalPlaysCount = 0,
                    TotalDurationSeconds = 0.0,
                    AverageTimePerTrackSeconds = 0,
                    TracksPerHour = 0,
                    AverageBpm = 0,
                    MinBpm = 0,
                    MaxBpm = 0,
                    DominantKey = null,
                    DominantKeyCount = 0,
                    DominantKeyPercentage = 0,
                    KeyDistribution = new(),
                    FastestTransition = null,
                    LongestTransition = null,
                    TopArtists = new(),
                    TopGenres = new(),
                    IsLiveSession = false
                };
            }

            int totalPlays = tracks.Sum(t => t.PlayCount);
            DateTime earliest = tracks.Min(t => t.PlayedAt);
            DateTime now = DateTime.Now;
            DateTime latest = tracks.Max(t => t.PlayedAt);
            bool isLive = (now - latest).TotalMinutes < 20;

            double totalDuration;
            if (isLive)
            {
                DateTime startPoint = sessionStartTime < earliest ? sessionStartTime : earliest;
                totalDuration = Math.Max(60.0, (now - startPoint).TotalSeconds);
            }
            else
            {
                var lastTrack = tracks.OrderByDescending(t => t.PlayedAt).FirstOrDefault();
                double lastDur = lastTrack != null && lastTrack.DurationSeconds > 0 ? lastTrack.DurationSeconds : 180.0;
                DateTime effectiveEnd = latest.AddSeconds(lastDur);
                totalDuration = Math.Max(60.0, (effectiveEnd - earliest).TotalSeconds);
            }

            double avgTime = totalDuration / count;
            double tracksPerHour = (count / totalDuration) * 3600.0;

            var validBpms = tracks.Where(t => t.Bpm > 0).Select(t => t.Bpm).ToList();
            double avgBpm = validBpms.Count > 0 ? validBpms.Average() : 0.0;
            double minBpm = validBpms.Count > 0 ? validBpms.Min() : 0.0;
            double maxBpm = validBpms.Count > 0 ? validBpms.Max() : 0.0;

            // Clés
            var keyCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var t in tracks)
            {
                string k = t.DisplayKey;
                if (!string.IsNullOrEmpty(k) && k != "--")
                {
                    keyCounts[k] = keyCounts.GetValueOrDefault(k, 0) + 1;
                }
            }
            int totalKeys = keyCounts.Values.Sum();
            var sortedKeys = keyCounts.OrderByDescending(kv => kv.Value)
                                      .Select(kv => (Key: kv.Key, Count: kv.Value, Percent: totalKeys > 0 ? (kv.Value * 100.0 / totalKeys) : 0.0))
                                      .ToList();

            // Transitions
            var chronTracks = tracks.OrderBy(t => t.PlayedAt).ToList();
            var transitions = new List<TransitionRecord>();
            for (int i = 0; i < chronTracks.Count - 1; i++)
            {
                var t1 = chronTracks[i];
                var t2 = chronTracks[i + 1];
                double diff = Math.Max(0, (t2.PlayedAt - t1.PlayedAt).TotalSeconds);
                if (diff >= 15.0)
                {
                    transitions.Add(new TransitionRecord
                    {
                        FromTrack = t1.DisplayTitle,
                        ToTrack = t2.DisplayTitle,
                        ElapsedSeconds = diff
                    });
                }
            }
            var fastest = transitions.OrderBy(t => t.ElapsedSeconds).FirstOrDefault();
            var longest = transitions.OrderByDescending(t => t.ElapsedSeconds).FirstOrDefault();

            // Top Artistes
            var artistCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var t in tracks)
            {
                string a = t.DisplayArtist.Trim();
                if (string.IsNullOrEmpty(a) || a.Equals("artiste inconnu", StringComparison.OrdinalIgnoreCase) || a.Equals("unknown", StringComparison.OrdinalIgnoreCase)) continue;
                artistCounts[a] = artistCounts.GetValueOrDefault(a, 0) + 1;
            }
            int totalArtistPlays = artistCounts.Values.Sum();
            var topArtists = artistCounts.OrderByDescending(kv => kv.Value)
                                         .Take(5)
                                         .Select(kv => new RankedRecord
                                         {
                                             Name = kv.Key,
                                             Count = kv.Value,
                                             Percent = totalArtistPlays > 0 ? (kv.Value * 100.0 / totalArtistPlays) : 0.0
                                         }).ToList();

            // Top Genres (User Request #1)
            var genreCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var t in tracks)
            {
                string g = t.Genre.Trim();
                if (string.IsNullOrEmpty(g) || g.Equals("unknown", StringComparison.OrdinalIgnoreCase) || g.Equals("inconnu", StringComparison.OrdinalIgnoreCase) || g.Equals("other", StringComparison.OrdinalIgnoreCase)) continue;
                // Capitalize first letter
                string formatted = char.ToUpper(g[0]) + (g.Length > 1 ? g.Substring(1).ToLowerInvariant() : "");
                genreCounts[formatted] = genreCounts.GetValueOrDefault(formatted, 0) + 1;
            }
            int totalGenrePlays = genreCounts.Values.Sum();
            var topGenres = genreCounts.OrderByDescending(kv => kv.Value)
                                       .Take(5)
                                       .Select(kv => new RankedRecord
                                       {
                                           Name = kv.Key,
                                           Count = kv.Value,
                                           Percent = totalGenrePlays > 0 ? (kv.Value * 100.0 / totalGenrePlays) : 0.0
                                       }).ToList();

            return new SetRecapStats
            {
                TotalTracksCount = count,
                TotalPlaysCount = totalPlays,
                TotalDurationSeconds = totalDuration,
                AverageTimePerTrackSeconds = avgTime,
                TracksPerHour = tracksPerHour,
                AverageBpm = avgBpm,
                MinBpm = minBpm,
                MaxBpm = maxBpm,
                DominantKey = sortedKeys.FirstOrDefault().Key,
                DominantKeyCount = sortedKeys.FirstOrDefault().Count,
                DominantKeyPercentage = sortedKeys.FirstOrDefault().Percent,
                KeyDistribution = sortedKeys.Take(4).ToList(),
                FastestTransition = fastest,
                LongestTransition = longest,
                TopArtists = topArtists,
                TopGenres = topGenres,
                IsLiveSession = isLive
            };
        }
    }

    public class SessionHistoryService : INotifyPropertyChanged
    {
        private static SessionHistoryService? _shared;
        public static SessionHistoryService Shared => _shared ??= new SessionHistoryService();

        private readonly SeratoDatabaseService _dbService;
        private List<SessionPlayedTrack> _playedTracks = new();
        private HashSet<string> _playedNormalizedTitles = new(StringComparer.OrdinalIgnoreCase);
        private DateTime _sessionStartTime;
        private int _playedCount = 0;
        private bool _isSyncing = false;

        public List<SessionPlayedTrack> PlayedTracks
        {
            get => _playedTracks;
            private set { _playedTracks = value; OnPropertyChanged(); }
        }

        public DateTime SessionStartTime
        {
            get => _sessionStartTime;
            private set { _sessionStartTime = value; OnPropertyChanged(); }
        }

        public int PlayedCount
        {
            get => _playedCount;
            private set { _playedCount = value; OnPropertyChanged(); }
        }

        public SessionHistoryService()
        {
            _dbService = new SeratoDatabaseService();
            _sessionStartTime = _dbService.FetchLatestSessionStartTime() ?? DateTime.Now;
            SyncWithDatabase();
        }

        public void ResetSession()
        {
            SessionStartTime = DateTime.Now;
            PlayedTracks = new();
            _playedNormalizedTitles.Clear();
            PlayedCount = 0;
            SeratoMonitorService.Shared.RefreshSuggestions();
        }

        public bool IsPlayed(Track track)
        {
            string norm = FavoriteCombosService.Normalize(track.DisplayTitle);
            if (_playedNormalizedTitles.Contains(norm)) return true;
            if (!string.IsNullOrEmpty(track.FileName))
            {
                if (_playedNormalizedTitles.Contains(FavoriteCombosService.Normalize(track.FileName))) return true;
            }
            return false;
        }

        public void RecordPlayedTrack(string title, string artist = "", string fileName = "", double durationSeconds = 30.0, double bpm = 0.0, string rawKey = "", string genre = "")
        {
            string norm = FavoriteCombosService.Normalize(title);
            if (string.IsNullOrEmpty(norm)) return;

            _playedNormalizedTitles.Add(norm);
            if (!string.IsNullOrEmpty(fileName))
            {
                _playedNormalizedTitles.Add(FavoriteCombosService.Normalize(fileName));
            }

            var existing = PlayedTracks.FirstOrDefault(t => FavoriteCombosService.Normalize(t.Title) == norm);
            if (existing != null)
            {
                existing.PlayCount++;
                existing.DurationSeconds = Math.Max(existing.DurationSeconds, durationSeconds);
                if (bpm > 0) existing.Bpm = bpm;
                if (!string.IsNullOrEmpty(rawKey)) existing.RawKey = rawKey;
                if (!string.IsNullOrEmpty(genre)) existing.Genre = genre;
            }
            else
            {
                var newTrack = new SessionPlayedTrack
                {
                    Id = $"session_{norm}",
                    Title = title,
                    Artist = artist,
                    FileName = fileName,
                    PlayedAt = DateTime.Now,
                    DurationSeconds = durationSeconds,
                    PlayCount = 1,
                    Bpm = bpm,
                    RawKey = rawKey,
                    Genre = genre
                };
                PlayedTracks.Insert(0, newTrack);
            }
            PlayedCount = PlayedTracks.Count;
            OnPropertyChanged(nameof(PlayedTracks));
        }

        public void SyncWithDatabase()
        {
            if (_isSyncing) return;
            _isSyncing = true;

            DateTime start = SessionStartTime;
            int thresholdSec = UserSettings.Shared.PlayedMinDurationSeconds;

            Task.Run(() =>
            {
                try
                {
                    var entries = _dbService.FetchSessionEntries(start);
                    var validByTitle = new Dictionary<string, SessionPlayedTrack>(StringComparer.OrdinalIgnoreCase);

                    foreach (var entry in entries)
                    {
                        bool isGenuine = entry.DurationSeconds >= thresholdSec || (entry.PlayedFlag == 1 && entry.DurationSeconds >= Math.Max(5.0, thresholdSec * 0.8));
                        if (!isGenuine) continue;

                        string norm = FavoriteCombosService.Normalize(entry.Title);
                        if (string.IsNullOrEmpty(norm)) continue;

                        if (validByTitle.TryGetValue(norm, out var existing))
                        {
                            existing.PlayCount++;
                            existing.DurationSeconds = Math.Max(existing.DurationSeconds, entry.DurationSeconds);
                            if (entry.StartTime > existing.PlayedAt) existing.PlayedAt = entry.StartTime;
                            if (existing.Bpm <= 0 && entry.Bpm > 0) existing.Bpm = entry.Bpm;
                            if (string.IsNullOrEmpty(existing.RawKey) && !string.IsNullOrEmpty(entry.RawKey)) existing.RawKey = entry.RawKey;
                            if (string.IsNullOrEmpty(existing.Genre) && !string.IsNullOrEmpty(entry.Genre)) existing.Genre = entry.Genre;
                        }
                        else
                        {
                            validByTitle[norm] = new SessionPlayedTrack
                            {
                                Id = $"session_{norm}",
                                Title = entry.Title,
                                Artist = entry.Artist,
                                FileName = entry.FileName,
                                PlayedAt = entry.StartTime,
                                DurationSeconds = entry.DurationSeconds,
                                PlayCount = 1,
                                Bpm = entry.Bpm,
                                RawKey = entry.RawKey,
                                Genre = entry.Genre
                            };
                        }
                    }

                    var sorted = validByTitle.Values.OrderByDescending(t => t.PlayedAt).ToList();
                    var titlesSet = new HashSet<string>(validByTitle.Keys, StringComparer.OrdinalIgnoreCase);

                    App.Current?.Dispatcher.Invoke(() =>
                    {
                        PlayedTracks = sorted;
                        _playedNormalizedTitles = titlesSet;
                        PlayedCount = sorted.Count;
                        _isSyncing = false;
                    });
                }
                catch
                {
                    _isSyncing = false;
                }
            });
        }

        public SetRecapStats ComputeCurrentStats()
        {
            return SetRecapStats.Compute(PlayedTracks, SessionStartTime);
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
