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
        public bool IsCurrentlyPlaying { get; set; } = false;
        public DateTime StartTime { get; set; } = DateTime.Now;
        public DateTime? EndTime { get; set; }

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

        public static (double Duration, bool IsPlayingNow) ComputeTotalPlaybackDuration(List<SessionPlayedTrack> tracks, DateTime now)
        {
            if (tracks == null || tracks.Count == 0) return (0.0, false);

            var intervals = new List<(DateTime Start, DateTime End)>();
            bool isPlayingNow = false;

            foreach (var t in tracks)
            {
                DateTime start = t.StartTime;
                DateTime end;
                if (t.IsCurrentlyPlaying)
                {
                    isPlayingNow = true;
                    end = now > start ? now : start;
                }
                else if (t.EndTime.HasValue)
                {
                    end = t.EndTime.Value > start ? t.EndTime.Value : start;
                }
                else
                {
                    double dur = t.DurationSeconds > 0 ? t.DurationSeconds : 180.0;
                    end = start.AddSeconds(dur);
                }

                if (end > start)
                {
                    intervals.Add((start, end));
                }
            }

            if (intervals.Count == 0) return (0.0, isPlayingNow);

            intervals.Sort((a, b) => a.Start.CompareTo(b.Start));

            var merged = new List<(DateTime Start, DateTime End)>();
            var current = intervals[0];

            for (int i = 1; i < intervals.Count; i++)
            {
                var next = intervals[i];
                if (next.Start <= current.End)
                {
                    if (next.End > current.End) current.End = next.End;
                }
                else
                {
                    merged.Add(current);
                    current = next;
                }
            }
            merged.Add(current);

            double total = merged.Sum(m => Math.Max(0.0, (m.End - m.Start).TotalSeconds));
            return (total, isPlayingNow);
        }

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
            DateTime now = DateTime.Now;
            var (totalDuration, isLive) = ComputeTotalPlaybackDuration(tracks, now);
            double effectiveDuration = Math.Max(totalDuration, count > 0 ? 1.0 : 0.0);

            double avgTime = count > 0 && effectiveDuration > 0 ? effectiveDuration / count : 0.0;
            double tracksPerHour = effectiveDuration > 0 ? (count / effectiveDuration) * 3600.0 : 0.0;

            var validBpms = tracks.Where(t => t.Bpm > 0).Select(t => t.Bpm).ToList();
            double avgBpm = validBpms.Count > 0 ? validBpms.Average() : 0.0;
            double minBpm = validBpms.Count > 0 ? validBpms.Min() : 0.0;
            double maxBpm = validBpms.Count > 0 ? validBpms.Max() : 0.0;

            // Clés (avec départage stable)
            var keyCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var keyLatestDate = new Dictionary<string, DateTime>(StringComparer.OrdinalIgnoreCase);
            foreach (var t in tracks)
            {
                string k = t.DisplayKey;
                if (!string.IsNullOrEmpty(k) && k != "--")
                {
                    keyCounts[k] = keyCounts.GetValueOrDefault(k, 0) + 1;
                    if (!keyLatestDate.TryGetValue(k, out var existingDate) || t.PlayedAt > existingDate)
                    {
                        keyLatestDate[k] = t.PlayedAt;
                    }
                }
            }
            int totalKeys = keyCounts.Values.Sum();
            var sortedKeys = keyCounts.OrderByDescending(kv => kv.Value)
                                      .ThenByDescending(kv => keyLatestDate.GetValueOrDefault(kv.Key, DateTime.MinValue))
                                      .ThenBy(kv => kv.Key)
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

            // Top Artistes (avec départage stable)
            var artistCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var artistLatestDate = new Dictionary<string, DateTime>(StringComparer.OrdinalIgnoreCase);
            foreach (var t in tracks)
            {
                string a = t.DisplayArtist.Trim();
                if (string.IsNullOrEmpty(a) || a.Equals("artiste inconnu", StringComparison.OrdinalIgnoreCase) || a.Equals("unknown", StringComparison.OrdinalIgnoreCase)) continue;
                artistCounts[a] = artistCounts.GetValueOrDefault(a, 0) + 1;
                if (!artistLatestDate.TryGetValue(a, out var existingDate) || t.PlayedAt > existingDate)
                {
                    artistLatestDate[a] = t.PlayedAt;
                }
            }
            int totalArtistPlays = artistCounts.Values.Sum();
            var topArtists = artistCounts.OrderByDescending(kv => kv.Value)
                                         .ThenByDescending(kv => artistLatestDate.GetValueOrDefault(kv.Key, DateTime.MinValue))
                                         .ThenBy(kv => kv.Key)
                                         .Take(5)
                                         .Select(kv => new RankedRecord
                                         {
                                             Name = kv.Key,
                                             Count = kv.Value,
                                             Percent = totalArtistPlays > 0 ? (kv.Value * 100.0 / totalArtistPlays) : 0.0
                                         }).ToList();

            // Top Genres (avec départage stable)
            var genreCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var genreLatestDate = new Dictionary<string, DateTime>(StringComparer.OrdinalIgnoreCase);
            foreach (var t in tracks)
            {
                string g = t.Genre.Trim();
                if (string.IsNullOrEmpty(g) || g.Equals("unknown", StringComparison.OrdinalIgnoreCase) || g.Equals("inconnu", StringComparison.OrdinalIgnoreCase) || g.Equals("other", StringComparison.OrdinalIgnoreCase)) continue;
                string formatted = char.ToUpper(g[0]) + (g.Length > 1 ? g.Substring(1).ToLowerInvariant() : "");
                genreCounts[formatted] = genreCounts.GetValueOrDefault(formatted, 0) + 1;
                if (!genreLatestDate.TryGetValue(formatted, out var existingDate) || t.PlayedAt > existingDate)
                {
                    genreLatestDate[formatted] = t.PlayedAt;
                }
            }
            int totalGenrePlays = genreCounts.Values.Sum();
            var topGenres = genreCounts.OrderByDescending(kv => kv.Value)
                                       .ThenByDescending(kv => genreLatestDate.GetValueOrDefault(kv.Key, DateTime.MinValue))
                                       .ThenBy(kv => kv.Key)
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

        private bool _isCurrentlyPlaying = false;
        public bool IsCurrentlyPlaying
        {
            get => _isCurrentlyPlaying;
            private set { _isCurrentlyPlaying = value; OnPropertyChanged(); }
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
            IsCurrentlyPlaying = false;
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

        public void RecordPlayedTrack(string title, string artist = "", string fileName = "", double durationSeconds = 30.0, double bpm = 0.0, string rawKey = "", string genre = "", bool isCurrentlyPlaying = true, DateTime? startTime = null, DateTime? endTime = null)
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
                existing.IsCurrentlyPlaying = isCurrentlyPlaying;
                if (startTime.HasValue) existing.StartTime = startTime.Value;
                if (endTime.HasValue) existing.EndTime = endTime.Value;
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
                    Genre = genre,
                    IsCurrentlyPlaying = isCurrentlyPlaying,
                    StartTime = startTime ?? DateTime.Now,
                    EndTime = endTime
                };
                PlayedTracks.Insert(0, newTrack);
            }
            PlayedCount = PlayedTracks.Count;
            IsCurrentlyPlaying = PlayedTracks.Any(t => t.IsCurrentlyPlaying);
            OnPropertyChanged(nameof(PlayedTracks));
        }

        public void SyncWithDatabase()
        {
            if (_isSyncing) return;
            _isSyncing = true;

            DateTime start = SessionStartTime;

            Task.Run(() =>
            {
                try
                {
                    var entries = _dbService.FetchSessionEntries(start);
                    var validByTitle = new Dictionary<string, SessionPlayedTrack>(StringComparer.OrdinalIgnoreCase);

                    foreach (var entry in entries)
                    {
                        // Seul le statut officiel Serato certifié (PlayedFlag == 1, fader vers le master) garantit qu'un morceau a été joué
                        bool isGenuine = entry.PlayedFlag == 1 && entry.DurationSeconds >= 3.0;
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
                            if (entry.IsCurrentlyPlaying)
                            {
                                existing.IsCurrentlyPlaying = true;
                                existing.EndTime = null;
                            }
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
                                Genre = entry.Genre,
                                IsCurrentlyPlaying = entry.IsCurrentlyPlaying,
                                StartTime = entry.StartTime,
                                EndTime = entry.EndTime
                            };
                        }
                    }

                    var sorted = validByTitle.Values.OrderByDescending(t => t.PlayedAt).ToList();
                    var titlesSet = new HashSet<string>(validByTitle.Keys, StringComparer.OrdinalIgnoreCase);
                    bool anyPlaying = sorted.Any(t => t.IsCurrentlyPlaying);

                    App.Current?.Dispatcher.Invoke(() =>
                    {
                        bool hasChanged = PlayedTracks.Count != sorted.Count || IsCurrentlyPlaying != anyPlaying;
                        if (!hasChanged)
                        {
                            for (int i = 0; i < sorted.Count; i++)
                            {
                                var t1 = PlayedTracks[i];
                                var t2 = sorted[i];
                                if (t1.Id != t2.Id || t1.Title != t2.Title || t1.Artist != t2.Artist ||
                                    t1.PlayCount != t2.PlayCount || t1.Bpm != t2.Bpm || t1.RawKey != t2.RawKey || t1.Genre != t2.Genre ||
                                    t1.IsCurrentlyPlaying != t2.IsCurrentlyPlaying)
                                {
                                    hasChanged = true;
                                    break;
                                }
                            }
                        }

                        if (hasChanged)
                        {
                            PlayedTracks = sorted;
                            _playedNormalizedTitles = titlesSet;
                            PlayedCount = sorted.Count;
                            IsCurrentlyPlaying = anyPlaying;
                        }
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
