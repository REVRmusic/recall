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

        public List<Track> FetchRoutineTransitions(Track currentTrack, int lookbackDays, int maxCount)
        {
            var result = new List<Track>();
            using var db = OpenDatabase();
            if (db == null) return result;

            long cutoffTime = DateTimeOffset.UtcNow.ToUnixTimeSeconds() - (lookbackDays * 86400L);
            string targetTitle = currentTrack.DisplayTitle.Trim().Replace("'", "''");
            string targetArtist = currentTrack.DisplayArtist.Trim().Replace("'", "''");

            try
            {
                // Requête optimisée : trouve les morceaux ayant succédé au morceau cible dans la même session
                string sql = $@"
                    SELECT next_e.name, next_e.artist, next_e.bpm, next_e.key,
                           next_e.file_name, next_e.portable_id, COUNT(*) as transition_count
                    FROM history_entry curr_e
                    JOIN history_entry next_e ON next_e.session_id = curr_e.session_id
                                             AND next_e.id > curr_e.id
                                             AND (next_e.start_time - curr_e.start_time) BETWEEN 30 AND 2700
                    WHERE curr_e.start_time >= {cutoffTime}
                      AND (
                          LOWER(curr_e.name) = LOWER('{targetTitle}')
                          OR (LOWER(curr_e.name) LIKE LOWER('%{targetTitle}%') AND LOWER(curr_e.artist) = LOWER('{targetArtist}'))
                      )
                    GROUP BY LOWER(next_e.name), LOWER(next_e.artist)
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

                    // Éviter de se suggérer soi-même
                    if (title.Equals(targetTitle, StringComparison.OrdinalIgnoreCase)) continue;

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
                        TransitionCount = count
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
                        SELECT ifnull(name, ''), ifnull(file_name, ''), (end_time - start_time) as duration
                        FROM history_entry
                        WHERE session_id = {latestSessionId};";

                    using var reader = cmd.ExecuteReader();
                    while (reader.Read())
                    {
                        string name = reader.GetString(0);
                        string fileName = reader.GetString(1);
                        long dur = reader.IsDBNull(2) ? 0 : reader.GetInt64(2);

                        if (dur >= minDurationSec || dur == 0)
                        {
                            if (!string.IsNullOrWhiteSpace(name)) set.Add(name.Trim());
                            else if (!string.IsNullOrWhiteSpace(fileName)) set.Add(Path.GetFileNameWithoutExtension(fileName).Trim());
                        }
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
    }
}
