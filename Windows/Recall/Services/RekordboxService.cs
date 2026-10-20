using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Xml;
using Recall.Models;

namespace Recall.Services
{
    public class RekordboxService
    {
        private static RekordboxService? _shared;
        public static RekordboxService Shared => _shared ??= new RekordboxService();

        public bool IsLoaded { get; private set; }
        public bool IsParsing { get; private set; }
        public int TotalTracksCount => _tracksList.Count;
        public int TotalTransitionsCount { get; private set; }
        public int TotalPlaylistsCount { get; private set; }
        public string CurrentXmlPath { get; private set; } = "";
        public DateTime? LastLoadedDate { get; private set; }
        public string? ErrorMessage { get; private set; }

        private readonly Dictionary<string, Track> _tracksById = new();
        private readonly List<Track> _tracksList = new();
        // transitionMap[fromTrackId][toTrackId] = count
        private readonly Dictionary<string, Dictionary<string, int>> _transitionMap = new();
        private DateTime? _lastXmlModificationDate;

        public RekordboxService()
        {
            LoadCollectionIfNeeded();
        }

        public void LoadCollectionIfNeeded()
        {
            string xmlPath = UserSettings.Shared.EffectiveRekordboxXmlPath;
            if (string.IsNullOrWhiteSpace(xmlPath) || !File.Exists(xmlPath)) return;

            DateTime modDate = File.GetLastWriteTimeUtc(xmlPath);
            if (IsLoaded && xmlPath == CurrentXmlPath && modDate == _lastXmlModificationDate)
            {
                return; // Déjà à jour
            }

            ReloadCollection(xmlPath);
        }

        public void ReloadCollection(string? path = null)
        {
            string targetPath = path ?? UserSettings.Shared.EffectiveRekordboxXmlPath;
            if (string.IsNullOrWhiteSpace(targetPath) || !File.Exists(targetPath))
            {
                ErrorMessage = $"Fichier XML introuvable : {targetPath}";
                return;
            }

            IsParsing = true;
            ErrorMessage = null;

            Task.Run(() =>
            {
                try
                {
                    DateTime modDate = File.GetLastWriteTimeUtc(targetPath);
                    var newTracksById = new Dictionary<string, Track>();
                    var newTracksList = new List<Track>();
                    var newTransitionMap = new Dictionary<string, Dictionary<string, int>>();
                    int playlistCount = 0;
                    int transitionsCount = 0;

                    using (var stream = File.OpenRead(targetPath))
                    using (var reader = XmlReader.Create(stream, new XmlReaderSettings { IgnoreWhitespace = true, IgnoreComments = true }))
                    {
                        bool isInsidePlaylists = false;
                        var currentPlaylist = new List<string>();
                        // Le XML Rekordbox ne contient pas l'heure de lecture : la durée d'une session
                        // est estimée par la somme des durées (TotalTime) de ses morceaux.
                        var trackDurationsById = new Dictionary<string, int>();

                        while (reader.Read())
                        {
                            if (reader.NodeType == XmlNodeType.Element)
                            {
                                if (reader.Name == "PLAYLISTS")
                                {
                                    isInsidePlaylists = true;
                                }
                                else if (reader.Name == "NODE")
                                {
                                    string? type = reader.GetAttribute("Type");
                                    if (type == "1")
                                    {
                                        currentPlaylist.Clear();
                                    }
                                }
                                else if (reader.Name == "TRACK")
                                {
                                    if (isInsidePlaylists)
                                    {
                                        string? key = reader.GetAttribute("Key");
                                        if (!string.IsNullOrEmpty(key))
                                        {
                                            currentPlaylist.Add(key);
                                        }
                                    }
                                    else
                                    {
                                        string? trackId = reader.GetAttribute("TrackID");
                                        if (!string.IsNullOrEmpty(trackId))
                                        {
                                            string name = reader.GetAttribute("Name") ?? "";
                                            string artist = reader.GetAttribute("Artist") ?? "";
                                            string tonality = reader.GetAttribute("Tonality") ?? "";
                                            string location = reader.GetAttribute("Location") ?? "";
                                            double bpm = 0;
                                            double.TryParse(reader.GetAttribute("AverageBpm"), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out bpm);

                                            string filePath = DecodeLocationUrl(location);
                                            string fileName = Path.GetFileName(filePath);

                                            var track = new Track
                                            {
                                                Id = $"rb-{trackId}",
                                                Title = name,
                                                Artist = artist,
                                                Bpm = bpm,
                                                RawKey = tonality,
                                                CamelotKey = CamelotKey.Parse(tonality),
                                                FilePath = filePath,
                                                FileName = fileName,
                                                PortableId = trackId
                                            };

                                            newTracksById[trackId] = track;
                                            newTracksList.Add(track);
                                            if (int.TryParse(reader.GetAttribute("TotalTime"), out int totalTime) && totalTime > 0)
                                            {
                                                trackDurationsById[trackId] = totalTime;
                                            }
                                        }
                                    }
                                }
                            }
                            else if (reader.NodeType == XmlNodeType.EndElement)
                            {
                                if (reader.Name == "NODE" && currentPlaylist.Count > 0)
                                {
                                    playlistCount++;
                                    int estimatedDuration = currentPlaylist.Sum(k => trackDurationsById.TryGetValue(k, out int d) ? d : 180);
                                    if (estimatedDuration < UserSettings.MinimumSessionDurationSeconds)
                                    {
                                        currentPlaylist.Clear();
                                        continue;
                                    }
                                    for (int i = 0; i < currentPlaylist.Count - 1; i++)
                                    {
                                        string fromKey = currentPlaylist[i];
                                        string toKey = currentPlaylist[i + 1];
                                        if (fromKey == toKey) continue;

                                        if (!newTransitionMap.TryGetValue(fromKey, out var destMap))
                                        {
                                            destMap = new Dictionary<string, int>();
                                            newTransitionMap[fromKey] = destMap;
                                        }

                                        destMap[toKey] = destMap.TryGetValue(toKey, out int c) ? c + 1 : 1;
                                        transitionsCount++;
                                    }
                                    currentPlaylist.Clear();
                                }
                            }
                        }
                    }

                    lock (_tracksById)
                    {
                        _tracksById.Clear();
                        foreach (var kv in newTracksById) _tracksById[kv.Key] = kv.Value;

                        _tracksList.Clear();
                        _tracksList.AddRange(newTracksList);

                        _transitionMap.Clear();
                        foreach (var kv in newTransitionMap) _transitionMap[kv.Key] = kv.Value;

                        TotalPlaylistsCount = playlistCount;
                        TotalTransitionsCount = transitionsCount;
                        CurrentXmlPath = targetPath;
                        _lastXmlModificationDate = modDate;
                        LastLoadedDate = DateTime.Now;
                        IsLoaded = true;
                        IsParsing = false;
                        ErrorMessage = null;
                    }
                }
                catch (Exception ex)
                {
                    IsParsing = false;
                    ErrorMessage = ex.Message;
                }
            });
        }

        public (List<Track> routines, List<Track> favorites, List<Track> harmonic) FindNextSuggestions(
            Track currentTrack,
            int maxResults = 30,
            int minTransitions = 1,
            double tolerancePercent = 8.0,
            bool harmonicFilter = false,
            bool bpmFilter = false,
            bool favoritesOnly = false)
        {
            var routines = new List<Track>();
            var favorites = new List<Track>();
            var harmonic = new List<Track>();

            if (!IsLoaded) return (routines, favorites, harmonic);

            lock (_tracksById)
            {
                string? refTrackId = ResolveTrackId(currentTrack);

                // 1. Routines d'enchaînements (avec cumul des variantes si activé)
                var cumulatedMap = new Dictionary<string, int>();
                var variantIds = new HashSet<string>();
                if (!string.IsNullOrEmpty(refTrackId)) variantIds.Add(refTrackId);

                if (UserSettings.Shared.CumulateVariantSuggestions)
                {
                    string refBase = Track.ExtractBaseTitle(currentTrack.DisplayTitle);
                    if (refBase.Length >= 3)
                    {
                        foreach (var cand in _tracksList)
                        {
                            string candBase = Track.ExtractBaseTitle(cand.DisplayTitle);
                            if (!candBase.Equals(refBase, StringComparison.OrdinalIgnoreCase) &&
                                candBase.IndexOf(refBase, StringComparison.OrdinalIgnoreCase) < 0 &&
                                refBase.IndexOf(candBase, StringComparison.OrdinalIgnoreCase) < 0) continue;

                            if (currentTrack.CamelotKey != null && cand.CamelotKey != null)
                            {
                                if (!cand.CamelotKey.Equals(currentTrack.CamelotKey)) continue;
                            }

                            if (currentTrack.Bpm > 0 && cand.Bpm > 0)
                            {
                                double diff = Math.Abs(cand.Bpm - currentTrack.Bpm);
                                double pct = diff / currentTrack.Bpm * 100.0;
                                if (pct > 4.0 && diff > 2.0) continue;
                            }

                            variantIds.Add(cand.Id);
                        }
                    }
                }

                foreach (var vId in variantIds)
                {
                    if (_transitionMap.TryGetValue(vId, out var nextMap))
                    {
                        foreach (var kv in nextMap)
                        {
                            if (variantIds.Contains(kv.Key)) continue;
                            cumulatedMap[kv.Key] = cumulatedMap.GetValueOrDefault(kv.Key, 0) + kv.Value;
                        }
                    }
                }

                if (cumulatedMap.Count > 0)
                {
                    foreach (var kv in cumulatedMap)
                    {
                        if (kv.Value < minTransitions) continue;
                        if (!_tracksById.TryGetValue(kv.Key, out var target)) continue;

                        var rel = currentTrack.CamelotKey?.GetRelationshipWith(target.CamelotKey);
                        double? bpmDiff = (currentTrack.Bpm > 0 && target.Bpm > 0) ? target.Bpm - currentTrack.Bpm : null;

                        if (harmonicFilter && !rel.IsCompatible()) continue;
                        if (bpmFilter && currentTrack.Bpm > 0 && target.Bpm > 0)
                        {
                            double pct = Math.Abs(target.Bpm - currentTrack.Bpm) / currentTrack.Bpm * 100.0;
                            if (pct > tolerancePercent) continue;
                        }

                        var item = new Track
                        {
                            Id = target.Id,
                            Title = target.Title,
                            Artist = target.Artist,
                            Bpm = target.Bpm,
                            RawKey = target.RawKey,
                            CamelotKey = target.CamelotKey,
                            FilePath = target.FilePath,
                            FileName = target.FileName,
                            PortableId = target.PortableId,
                            TransitionCount = kv.Value,
                            HarmonicRelation = rel,
                            BpmDiff = bpmDiff,
                            IsFavorite = FavoriteCombosService.Shared.IsComboFavorite(currentTrack, target)
                        };

                        routines.Add(item);
                    }

                    routines = routines.OrderByDescending(t => t.TransitionCount)
                                       .ThenByDescending(t => t.HarmonicRelation.IsCompatible())
                                       .ToList();
                }

                // 2. Favoris mémorisés dans Recall
                var allFavs = FavoriteCombosService.Shared.GetFavoriteTracks(currentTrack);
                foreach (var fav in allFavs)
                {
                    fav.IsFavorite = true;
                    favorites.Add(fav);
                }

                if (favoritesOnly) return (new List<Track>(), favorites, new List<Track>());

                // 3. Suggestions harmoniques globales
                int needed = Math.Max(0, maxResults - routines.Count);
                if (needed > 0 && currentTrack.CamelotKey != null)
                {
                    var alreadyIds = new HashSet<string>(routines.Select(r => r.Id).Concat(favorites.Select(f => f.Id)));
                    alreadyIds.Add(currentTrack.Id);

                    foreach (var candidate in _tracksList)
                    {
                        if (alreadyIds.Contains(candidate.Id)) continue;
                        if (candidate.CamelotKey == null) continue;

                        var rel = currentTrack.CamelotKey.GetRelationshipWith(candidate.CamelotKey);
                        if (!rel.IsCompatible()) continue;

                        double? bpmDiff = null;
                        if (currentTrack.Bpm > 0 && candidate.Bpm > 0)
                        {
                            bpmDiff = candidate.Bpm - currentTrack.Bpm;
                            double pct = Math.Abs(candidate.Bpm - currentTrack.Bpm) / currentTrack.Bpm * 100.0;
                            if (bpmFilter && pct > tolerancePercent) continue;
                        }
                        else if (bpmFilter) continue;

                        var hTrack = new Track
                        {
                            Id = candidate.Id,
                            Title = candidate.Title,
                            Artist = candidate.Artist,
                            Bpm = candidate.Bpm,
                            RawKey = candidate.RawKey,
                            CamelotKey = candidate.CamelotKey,
                            FilePath = candidate.FilePath,
                            FileName = candidate.FileName,
                            PortableId = candidate.PortableId,
                            TransitionCount = 0,
                            HarmonicRelation = rel,
                            BpmDiff = bpmDiff,
                            IsFavorite = FavoriteCombosService.Shared.IsComboFavorite(currentTrack, candidate)
                        };

                        harmonic.Add(hTrack);
                        if (harmonic.Count >= needed * 2) break;
                    }

                    harmonic = harmonic.OrderByDescending(t => HarmonicScore(t.HarmonicRelation))
                                       .ThenBy(t => Math.Abs(t.BpmDiff ?? 999))
                                       .Take(needed)
                                       .ToList();
                }
            }

            return (routines, favorites, harmonic);
        }

        private static int HarmonicScore(HarmonicRelation? rel) => rel switch
        {
            HarmonicRelation.Exact => 4,
            HarmonicRelation.Adjacent => 3,
            HarmonicRelation.Relative => 2,
            HarmonicRelation.EnergyBoost => 1,
            _ => 0
        };

        public List<Track> SearchTracks(string query, int limit = 30)
        {
            string q = (query ?? "").Trim().ToLowerInvariant();
            if (string.IsNullOrEmpty(q)) return new List<Track>();

            lock (_tracksById)
            {
                return _tracksList.Where(t =>
                    t.Title.ToLowerInvariant().Contains(q) ||
                    t.Artist.ToLowerInvariant().Contains(q) ||
                    t.FileName.ToLowerInvariant().Contains(q)
                ).Take(limit).ToList();
            }
        }

        public Track? FindTrackByFile(string filePath, string fileName)
        {
            LoadCollectionIfNeeded();
            string cleanFn = (fileName ?? "").ToLowerInvariant();
            string cleanPath = (filePath ?? "").ToLowerInvariant();

            lock (_tracksById)
            {
                foreach (var track in _tracksList)
                {
                    if (!string.IsNullOrEmpty(track.FilePath) && track.FilePath.ToLowerInvariant() == cleanPath)
                    {
                        return track;
                    }
                    if (!string.IsNullOrEmpty(track.FileName) && track.FileName.ToLowerInvariant() == cleanFn)
                    {
                        return track;
                    }
                }
            }
            return null;
        }

        private string? ResolveTrackId(Track track)
        {
            if (_tracksById.ContainsKey(track.PortableId)) return track.PortableId;

            string cleanTitle = FavoriteCombosService.Normalize(track.DisplayTitle);
            string cleanArtist = FavoriteCombosService.Normalize(track.DisplayArtist);

            foreach (var candidate in _tracksList)
            {
                if (FavoriteCombosService.Normalize(candidate.DisplayTitle) == cleanTitle)
                {
                    if (string.IsNullOrEmpty(cleanArtist) || FavoriteCombosService.Normalize(candidate.DisplayArtist) == cleanArtist)
                    {
                        return candidate.PortableId;
                    }
                }
            }
            return null;
        }

        private static string DecodeLocationUrl(string location)
        {
            if (string.IsNullOrWhiteSpace(location)) return "";
            string cleaned = location;
            if (cleaned.StartsWith("file://localhost/")) cleaned = cleaned.Substring("file://localhost/".Length);
            else if (cleaned.StartsWith("file://localhost")) cleaned = cleaned.Substring("file://localhost".Length);
            else if (cleaned.StartsWith("file:///")) cleaned = cleaned.Substring("file:///".Length);

            string decoded = Uri.UnescapeDataString(cleaned);
            // Conversion slash vers backslash pour Windows si chemin de lecteur (ex: C:/ -> C:\)
            if (Regex.IsMatch(decoded, @"^[a-zA-Z]:/"))
            {
                decoded = decoded.Replace('/', '\\');
            }
            return decoded;
        }
    }
}
