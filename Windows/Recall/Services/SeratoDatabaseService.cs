using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.Data.Sqlite;
using Recall.Models;

namespace Recall.Services
{
    public class ActiveDecksState
    {
        public Track? Deck1 { get; }
        public Track? Deck2 { get; }
        public int LatestEntryId { get; }
        public bool HasActiveSession { get; }

        public ActiveDecksState(Track? deck1, Track? deck2, int latestEntryId, bool hasActiveSession)
        {
            Deck1 = deck1;
            Deck2 = deck2;
            LatestEntryId = latestEntryId;
            HasActiveSession = hasActiveSession;
        }
    }

    public class SeratoDatabaseService
    {
        private readonly string _dbPath;

        public SeratoDatabaseService(string? databasePath = null)
        {
            _dbPath = databasePath ?? UserSettings.Shared.EffectiveDatabasePath;
        }

        private SqliteConnection? OpenDatabase()
        {
            if (string.IsNullOrEmpty(_dbPath) || !File.Exists(_dbPath)) return null;

            try
            {
                var builder = new SqliteConnectionStringBuilder
                {
                    DataSource = _dbPath,
                    Mode = SqliteOpenMode.ReadOnly,
                    Cache = SqliteCacheMode.Shared
                };

                var connection = new SqliteConnection(builder.ConnectionString);
                connection.Open();

                using (var cmd = connection.CreateCommand())
                {
                    cmd.CommandText = "PRAGMA query_only = ON; PRAGMA busy_timeout = 2000;";
                    cmd.ExecuteNonQuery();
                }

                return connection;
            }
            catch
            {
                return null;
            }
        }

        public ActiveDecksState FetchActiveDecks()
        {
            using var db = OpenDatabase();
            if (db == null)
            {
                return new ActiveDecksState(null, null, -1, false);
            }

            long latestSessionId = -1;
            long sessionEndTime = -1;

            try
            {
                using (var cmd = db.CreateCommand())
                {
                    cmd.CommandText = "SELECT id, end_time FROM history_session ORDER BY id DESC LIMIT 1;";
                    using var reader = cmd.ExecuteReader();
                    if (reader.Read())
                    {
                        latestSessionId = reader.GetInt64(0);
                        sessionEndTime = reader.IsDBNull(1) ? 0 : reader.GetInt64(1);
                    }
                }

                if (latestSessionId <= 0 || sessionEndTime > 0)
                {
                    return new ActiveDecksState(null, null, -1, false);
                }

                Track? deck1 = null;
                Track? deck2 = null;
                int maxEntryId = -1;

                using (var cmd = db.CreateCommand())
                {
                    cmd.CommandText = $@"
                        SELECT id, asset_id, ifnull(name, ''), ifnull(artist, ''), ifnull(bpm, 0.0),
                               ifnull(key, ''), ifnull(file_name, ''), ifnull(portable_id, ''),
                               ifnull(deck, ''), start_time, end_time, ifnull(length_sec, 0)
                        FROM history_entry
                        WHERE session_id = {latestSessionId}
                        ORDER BY id DESC;";

                    using var reader = cmd.ExecuteReader();
                    while (reader.Read())
                    {
                        int id = reader.GetInt32(0);
                        if (maxEntryId == -1) maxEntryId = id;

                        int assetId = reader.IsDBNull(1) ? 0 : reader.GetInt32(1);
                        string title = reader.GetString(2);
                        string artist = reader.GetString(3);
                        double bpm = reader.GetDouble(4);
                        string key = reader.GetString(5);
                        string fileName = reader.GetString(6);
                        string portableId = reader.GetString(7);
                        string deck = reader.GetString(8);
                        long endTime = reader.IsDBNull(10) ? 0 : reader.GetInt64(10);

                        // Si la piste est déjà terminée / éjectée, on continue
                        if (endTime > 0) continue;

                        string resolvedPath = ResolveAudioFilePath(portableId, fileName) ?? "";

                        var track = new Track
                        {
                            AssetId = assetId,
                            HistoryEntryId = id,
                            Title = title,
                            Artist = artist,
                            Bpm = bpm,
                            RawKey = key,
                            CamelotKey = CamelotKey.Parse(key),
                            FilePath = resolvedPath,
                            FileName = fileName,
                            PortableId = portableId,
                            Deck = deck
                        };

                        if (deck == "1" && deck1 == null) deck1 = track;
                        else if (deck == "2" && deck2 == null) deck2 = track;

                        if (deck1 != null && deck2 != null) break;
                    }
                }

                return new ActiveDecksState(deck1, deck2, maxEntryId, true);
            }
            catch
            {
                return new ActiveDecksState(null, null, -1, false);
            }
        }

        public List<Track> FetchRoutineTransitions(Track currentTrack, int lookbackDays, int maxCount, string direction = "next")
        {
            if (direction == "all")
            {
                var nextList = FetchRoutineTransitions(currentTrack, lookbackDays, maxCount * 2, "next");
                var prevList = FetchRoutineTransitions(currentTrack, lookbackDays, maxCount * 2, "previous");

                var map = new Dictionary<string, Track>(StringComparer.OrdinalIgnoreCase);
                foreach (var trk in nextList)
                {
                    map[trk.DisplayTitle] = trk;
                }

                foreach (var trk in prevList)
                {
                    if (map.TryGetValue(trk.DisplayTitle, out var existing))
                    {
                        existing.TransitionCount += trk.TransitionCount;
                        existing.Direction = "all";
                    }
                    else
                    {
                        map[trk.DisplayTitle] = trk;
                    }
                }

                var list = new List<Track>(map.Values);
                list.Sort((a, b) => b.TransitionCount.CompareTo(a.TransitionCount));
                if (list.Count > maxCount) list = list.GetRange(0, maxCount);
                return list;
            }

            var result = new List<Track>();
            using var db = OpenDatabase();
            if (db == null) return result;

            long cutoffTime = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - (lookbackDays * 86400L);
            string targetTitle = currentTrack.DisplayTitle.Trim().Replace("'", "''");
            string targetArtist = currentTrack.DisplayArtist.Trim().Replace("'", "''");
            string baseTitle = Track.ExtractBaseTitle(currentTrack.DisplayTitle).Trim().Replace("'", "''");

            string matchCondition;
            if (UserSettings.Shared.CumulateVariantSuggestions && baseTitle.Length >= 3)
            {
                string rawKey = currentTrack.RawKey.Trim().Replace("'", "''");
                double refBpm = currentTrack.Bpm;
                string keyFilter = !string.IsNullOrEmpty(rawKey) ? $"AND LOWER(curr_e.key) = LOWER('{rawKey}')" : "";
                string bpmFilter = refBpm > 0 ? $"AND ABS(curr_e.bpm - {refBpm.ToString(System.Globalization.CultureInfo.InvariantCulture)}) <= 3.5" : "";
                matchCondition = $@"
                      (
                          LOWER(curr_e.name) = LOWER('{targetTitle}')
                          OR (
                              (LOWER(curr_e.name) LIKE LOWER('%{baseTitle}%') OR LOWER(curr_e.file_name) LIKE LOWER('%{baseTitle}%'))
                              {keyFilter}
                              {bpmFilter}
                          )
                      )";
            }
            else
            {
                matchCondition = $@"
                      (
                          LOWER(curr_e.name) = LOWER('{targetTitle}')
                          OR (LOWER(curr_e.name) LIKE LOWER('%{targetTitle}%') AND LOWER(curr_e.artist) = LOWER('{targetArtist}'))
                      )";
            }

            try
            {
                string joinClause = direction == "previous"
                    ? @"JOIN history_entry target_e ON target_e.session_id = curr_e.session_id
                                                  AND target_e.id < curr_e.id
                                                  AND (curr_e.start_time - target_e.start_time) BETWEEN 30 AND 2700"
                    : @"JOIN history_entry target_e ON target_e.session_id = curr_e.session_id
                                                  AND target_e.id > curr_e.id
                                                  AND (target_e.start_time - curr_e.start_time) BETWEEN 30 AND 2700";

                string sql = $@"
                    SELECT target_e.name, target_e.artist, target_e.bpm, target_e.key,
                           target_e.file_name, target_e.portable_id, COUNT(*) as transition_count
                    FROM history_entry curr_e
                    {joinClause}
                    WHERE curr_e.start_time >= {cutoffTime}
                      AND {matchCondition}
                    GROUP BY LOWER(target_e.name), LOWER(target_e.artist)
                    ORDER BY transition_count DESC
                    LIMIT {maxCount};";

                using var cmd = db.CreateCommand();
                cmd.CommandText = sql;
                using var reader = cmd.ExecuteReader();

                while (reader.Read())
                {
                    string title = reader.GetString(0);
                    string artist = reader.GetString(1);
                    double bpm = reader.GetDouble(2);
                    string key = reader.GetString(3);
                    string fileName = reader.GetString(4);
                    string portableId = reader.GetString(5);
                    int count = reader.GetInt32(6);

                    // Éviter de se suggérer soi-même ou une autre version du même morceau
                    if (title.Equals(targetTitle, StringComparison.OrdinalIgnoreCase)) continue;
                    if (UserSettings.Shared.CumulateVariantSuggestions && baseTitle.Length >= 3 && title.IndexOf(baseTitle, StringComparison.OrdinalIgnoreCase) >= 0) continue;

                    var candidate = new Track
                    {
                        Title = title,
                        Artist = artist,
                        Bpm = bpm,
                        RawKey = key,
                        CamelotKey = CamelotKey.Parse(key),
                        FileName = fileName,
                        PortableId = portableId,
                        FilePath = ResolveAudioFilePath(portableId, fileName),
                        TransitionCount = count,
                        Direction = direction
                    };

                    if (currentTrack.CamelotKey != null && candidate.CamelotKey != null)
                    {
                        candidate.HarmonicRelation = currentTrack.CamelotKey.Relationship(candidate.CamelotKey);
                    }

                    if (currentTrack.Bpm > 0 && candidate.Bpm > 0)
                    {
                        candidate.BpmDiff = candidate.Bpm - currentTrack.Bpm;
                    }

                    result.Add(candidate);
                }
            }
            catch { }

            return result;
        }

        public HashSet<string> FetchPlayedTrackTitlesInCurrentSession(int minDurationSec = 25)
        {
            var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using var db = OpenDatabase();
            if (db == null) return set;

            try
            {
                long latestSessionId = -1;
                using (var cmd = db.CreateCommand())
                {
                    cmd.CommandText = "SELECT id FROM history_session ORDER BY id DESC LIMIT 1;";
                    var obj = cmd.ExecuteScalar();
                    if (obj != null && obj != DBNull.Value) latestSessionId = Convert.ToInt64(obj);
                }

                if (latestSessionId <= 0) return set;

                using (var cmd = db.CreateCommand())
                {
                    cmd.CommandText = $@"
                        SELECT ifnull(name, ''), ifnull(file_name, '')
                        FROM history_entry
                        WHERE session_id = {latestSessionId} AND played = 1;";

                    using var reader = cmd.ExecuteReader();
                    while (reader.Read())
                    {
                        string name = reader.GetString(0);
                        string fileName = reader.GetString(1);

                        if (!string.IsNullOrWhiteSpace(name)) set.Add(name.Trim());
                        else if (!string.IsNullOrWhiteSpace(fileName)) set.Add(Path.GetFileNameWithoutExtension(fileName).Trim());
                    }
                }
            }
            catch { }

            return set;
        }

        public string? ResolveAudioFilePath(string portableId, string fileName)
        {
            if (string.IsNullOrEmpty(portableId) && string.IsNullOrEmpty(fileName)) return null;

            // 1. Chemin direct s'il existe
            if (!string.IsNullOrEmpty(portableId) && File.Exists(portableId)) return portableId;

            // 2. Normalisation du chemin Windows
            string normalized = portableId.Replace('/', '\\');
            if (File.Exists(normalized)) return normalized;

            // 3. Recherche dans le dossier Musique standard Windows
            string music = Environment.GetFolderPath(Environment.SpecialFolder.MyMusic);
            if (!string.IsNullOrEmpty(fileName))
            {
                string candMusic = Path.Combine(music, fileName);
                if (File.Exists(candMusic)) return candMusic;

                string candSerato = Path.Combine(music, "_Serato_", fileName);
                if (File.Exists(candSerato)) return candSerato;
            }

            // 4. Recherche sur les disques Windows (C:\, D:\, E:\, etc.)
            try
            {
                var drives = DriveInfo.GetDrives().Where(d => d.IsReady);
                foreach (var drive in drives)
                {
                    if (!string.IsNullOrEmpty(fileName))
                    {
                        string driveSerato = Path.Combine(drive.RootDirectory.FullName, "_Serato_", fileName);
                        if (File.Exists(driveSerato)) return driveSerato;
                    }

                    if (!string.IsNullOrEmpty(normalized))
                    {
                        // Si le chemin relatif commence sans lettre de lecteur
                        string driveCand = Path.Combine(drive.RootDirectory.FullName, normalized.TrimStart('\\'));
                        if (File.Exists(driveCand)) return driveCand;
                    }
                }
            }
            catch { }

            return null;
        }

        public Track? FindTrackByFile(string filePath, string fileName)
        {
            using var connection = OpenDatabase();
            if (connection == null) return null;

            try
            {
                using var cmd = connection.CreateCommand();
                cmd.CommandText = @"
                    SELECT id, ifnull(name, ''), ifnull(artist, ''), ifnull(bpm, 0.0), ifnull(key, ''), ifnull(file_name, ''), ifnull(portable_id, '')
                    FROM asset
                    WHERE file_name = @fileName OR portable_id = @filePath OR portable_id = @fileName
                    LIMIT 1;";
                cmd.Parameters.AddWithValue("@fileName", fileName);
                cmd.Parameters.AddWithValue("@filePath", filePath);

                using var reader = cmd.ExecuteReader();
                if (reader.Read())
                {
                    int assetId = reader.GetInt32(0);
                    string title = reader.GetString(1);
                    string artist = reader.GetString(2);
                    double bpm = reader.GetDouble(3);
                    string key = reader.GetString(4);
                    string fn = reader.GetString(5);
                    string pid = reader.GetString(6);

                    string? resolved = ResolveAudioFilePath(pid, fn) ?? (File.Exists(filePath) ? filePath : null);

                    return new Track
                    {
                        AssetId = assetId,
                        Title = string.IsNullOrEmpty(title) ? Path.GetFileNameWithoutExtension(fileName) : title,
                        Artist = artist,
                        Bpm = bpm,
                        RawKey = key,
                        CamelotKey = CamelotKey.Parse(key),
                        FilePath = resolved,
                        FileName = string.IsNullOrEmpty(fn) ? fileName : fn,
                        PortableId = pid
                    };
                }
            }
            catch { }

            return null;
        }

        public List<Track> SearchTracks(string query, int limit = 30)
        {
            var results = new List<Track>();
            string trimmed = (query ?? "").Trim();
            if (trimmed.Length < 2) return results;

            using var connection = OpenDatabase();
            if (connection == null) return results;

            try
            {
                var tokens = trimmed.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (tokens.Length == 0) return results;

                var whereParts = new List<string>();
                using var cmd = connection.CreateCommand();

                for (int i = 0; i < tokens.Length; i++)
                {
                    string pName = $"@p{i}";
                    whereParts.Add($"(name LIKE {pName} OR artist LIKE {pName} OR file_name LIKE {pName})");
                    cmd.Parameters.AddWithValue(pName, $"%{tokens[i]}%");
                }

                string whereClause = string.Join(" AND ", whereParts);
                cmd.CommandText = $@"
                    SELECT id, ifnull(name, ''), ifnull(artist, ''), ifnull(bpm, 0.0), ifnull(key, ''), ifnull(file_name, ''), ifnull(portable_id, '')
                    FROM asset
                    WHERE {whereClause}
                    ORDER BY id DESC
                    LIMIT {limit};";

                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    int assetId = reader.GetInt32(0);
                    string title = reader.GetString(1);
                    string artist = reader.GetString(2);
                    double bpm = reader.GetDouble(3);
                    string key = reader.GetString(4);
                    string fn = reader.GetString(5);
                    string pid = reader.GetString(6);

                    string? resolved = ResolveAudioFilePath(pid, fn);

                    results.Add(new Track
                    {
                        AssetId = assetId,
                        Title = string.IsNullOrEmpty(title) ? Path.GetFileNameWithoutExtension(fn) : title,
                        Artist = artist,
                        Bpm = bpm,
                        RawKey = key,
                        CamelotKey = CamelotKey.Parse(key),
                        FilePath = resolved,
                        FileName = fn,
                        PortableId = pid
                    });
                }
            }
            catch { }

            return results;
        }

        public class RawSessionEntry
        {
            public int Id { get; set; }
            public string Title { get; set; } = "";
            public string Artist { get; set; } = "";
            public double Bpm { get; set; }
            public string RawKey { get; set; } = "";
            public string Genre { get; set; } = "";
            public string FileName { get; set; } = "";
            public DateTime StartTime { get; set; }
            public DateTime? EndTime { get; set; }
            public double DurationSeconds { get; set; }
            public bool IsCurrentlyPlaying { get; set; }
            public int PlayedFlag { get; set; }
        }

        public List<RawSessionEntry> FetchSessionEntries(DateTime since)
        {
            var entries = new List<RawSessionEntry>();
            using var connection = OpenDatabase();
            if (connection == null) return entries;

            long sinceUnix = ((DateTimeOffset)since.ToUniversalTime()).ToUnixTimeSeconds();
            long nowUnix = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

            try
            {
                using var cmd = connection.CreateCommand();
                cmd.CommandText = $@"
                    SELECT id, ifnull(name, ''), ifnull(artist, ''), ifnull(bpm, 0.0), ifnull(key, ''), ifnull(file_name, ''),
                           start_time, end_time, played, ifnull(genre, '')
                    FROM history_entry
                    WHERE start_time >= {sinceUnix}
                    ORDER BY start_time ASC;";

                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    int id = reader.GetInt32(0);
                    string name = reader.GetString(1);
                    string artist = reader.GetString(2);
                    double bpm = reader.GetDouble(3);
                    string key = reader.GetString(4);
                    string fn = reader.GetString(5);
                    long startUnix = reader.IsDBNull(6) ? 0 : reader.GetInt64(6);
                    long endUnix = reader.IsDBNull(7) ? 0 : reader.GetInt64(7);
                    int played = reader.IsDBNull(8) ? 0 : reader.GetInt32(8);
                    string genre = reader.GetString(9);

                    DateTime startDate = DateTimeOffset.FromUnixTimeSeconds(startUnix).LocalDateTime;
                    DateTime? endDate = null;
                    double duration = 0.0;
                    bool isCurrent = false;

                    if (endUnix > startUnix)
                    {
                        endDate = DateTimeOffset.FromUnixTimeSeconds(endUnix).LocalDateTime;
                        duration = (double)(endUnix - startUnix);
                    }
                    else
                    {
                        long elapsed = nowUnix - startUnix;
                        if (elapsed >= 0 && elapsed <= 900)
                        {
                            isCurrent = true;
                            duration = elapsed;
                        }
                        else
                        {
                            isCurrent = false;
                            duration = 180.0;
                        }
                    }

                    string cleanTitle = !string.IsNullOrEmpty(name) ? name : Path.GetFileNameWithoutExtension(fn);

                    entries.Add(new RawSessionEntry
                    {
                        Id = id,
                        Title = cleanTitle,
                        Artist = artist,
                        Bpm = bpm,
                        RawKey = key,
                        Genre = genre,
                        FileName = fn,
                        StartTime = startDate,
                        EndTime = endDate,
                        DurationSeconds = duration,
                        IsCurrentlyPlaying = isCurrent,
                        PlayedFlag = played
                    });
                }
            }
            catch { }

            return entries;
        }

        public DateTime? FetchLatestSessionStartTime()
        {
            using var connection = OpenDatabase();
            if (connection == null) return null;

            try
            {
                using var cmd = connection.CreateCommand();
                cmd.CommandText = "SELECT start_time FROM history_session ORDER BY id DESC LIMIT 1;";
                var obj = cmd.ExecuteScalar();
                if (obj != null && obj != DBNull.Value)
                {
                    long startUnix = Convert.ToInt64(obj);
                    if (startUnix > 0)
                    {
                        return DateTimeOffset.FromUnixTimeSeconds(startUnix).LocalDateTime;
                    }
                }
            }
            catch { }

            return null;
        }
    }
}
