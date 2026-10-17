using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows.Threading;
using Recall.Models;

namespace Recall.Services
{
    public class SeratoMonitorService : INotifyPropertyChanged
    {
        private static SeratoMonitorService? _shared;
        public static SeratoMonitorService Shared => _shared ??= new SeratoMonitorService();

        private readonly SeratoDatabaseService _dbService;
        private readonly DispatcherTimer _timer;

        private Track? _currentTrack;
        private Track? _deck1Track;
        private Track? _deck2Track;
        private string _activeDeckSelection = "AUTO"; // "AUTO", "1", "2"
        private List<Track> _suggestions = new();
        private List<Track> _historySuggestions = new();
        private List<Track> _favoriteSuggestions = new();
        private HashSet<string> _playedTitlesInSession = new(StringComparer.OrdinalIgnoreCase);
        private bool _isSeratoConnected = false;
        private bool _isRekordboxConnected = false;
        private string _activeDJSoftware = "serato";
        private Track? _manualTrackOverride = null;
        private int _playedCount = 0;

        public Track? CurrentTrack
        {
            get => _currentTrack;
            set { if (_currentTrack != value) { _currentTrack = value; OnPropertyChanged(); } }
        }

        public Track? Deck1Track
        {
            get => _deck1Track;
            set { if (_deck1Track != value) { _deck1Track = value; OnPropertyChanged(); } }
        }

        public Track? Deck2Track
        {
            get => _deck2Track;
            set { if (_deck2Track != value) { _deck2Track = value; OnPropertyChanged(); } }
        }

        public string ActiveDJSoftware
        {
            get => _activeDJSoftware;
            set { if (_activeDJSoftware != value) { _activeDJSoftware = value; OnPropertyChanged(); } }
        }

        public bool IsRekordboxConnected
        {
            get => _isRekordboxConnected;
            set { if (_isRekordboxConnected != value) { _isRekordboxConnected = value; OnPropertyChanged(); } }
        }

        public string ActiveDeckSelection
        {
            get => _activeDeckSelection;
            set
            {
                if (_activeDeckSelection != value)
                {
                    _activeDeckSelection = value;
                    OnPropertyChanged();
                    UpdateCurrentTrackFromSelection();
                    RefreshSuggestions();
                }
            }
        }

        public List<Track> Suggestions
        {
            get => _suggestions;
            set { _suggestions = value; OnPropertyChanged(); }
        }

        public bool IsSeratoConnected
        {
            get => _isSeratoConnected;
            set { if (_isSeratoConnected != value) { _isSeratoConnected = value; OnPropertyChanged(); } }
        }

        public int PlayedCount
        {
            get => _playedCount;
            set { if (_playedCount != value) { _playedCount = value; OnPropertyChanged(); } }
        }

        public SeratoMonitorService()
        {
            _dbService = new SeratoDatabaseService();
            _timer = new DispatcherTimer
            {
                Interval = TimeSpan.FromMilliseconds(1500)
            };
            _timer.Tick += (s, e) => PollSoftware();
            _timer.Start();

            // Premier polling immédiat
            PollSoftware();
        }

        public void PollSoftware()
        {
            bool isSeratoRunning = false;
            bool isRekordboxRunning = false;

            try
            {
                isSeratoRunning = System.Diagnostics.Process.GetProcessesByName("Serato DJ Pro").Length > 0;
                isRekordboxRunning = System.Diagnostics.Process.GetProcessesByName("rekordbox").Length > 0;
            }
            catch { }

            IsSeratoConnected = isSeratoRunning;
            IsRekordboxConnected = isRekordboxRunning;

            string mode = UserSettings.Shared.DjSoftwareMode;
            string effective = mode switch
            {
                "auto" => (isRekordboxRunning && !isSeratoRunning) ? "rekordbox" : "serato",
                "rekordbox" => "rekordbox",
                _ => "serato"
            };

            ActiveDJSoftware = effective;

            if (effective == "rekordbox")
            {
                RekordboxService.Shared.LoadCollectionIfNeeded();
                Deck1Track = null;
                Deck2Track = null;

                if (_manualTrackOverride != null)
                {
                    if (CurrentTrack?.Id != _manualTrackOverride.Id)
                    {
                        CurrentTrack = _manualTrackOverride;
                        RefreshSuggestions();
                    }
                }
                else if (!isRekordboxRunning && CurrentTrack != null)
                {
                    CurrentTrack = null;
                    Suggestions = new();
                }
                return;
            }

            // Serato
            var state = _dbService.FetchActiveDecks();
            Deck1Track = state.Deck1;
            Deck2Track = state.Deck2;

            _playedTitlesInSession = _dbService.FetchPlayedTrackTitlesInCurrentSession(UserSettings.Shared.PlayedMinDurationSeconds);
            PlayedCount = _playedTitlesInSession.Count;

            UpdateCurrentTrackFromSelection();
        }

        public void SetManualReferenceTrack(Track track)
        {
            _manualTrackOverride = track;
            CurrentTrack = track;
            RefreshSuggestions();
        }

        public void ClearManualOverride()
        {
            _manualTrackOverride = null;
            if (ActiveDJSoftware == "rekordbox")
            {
                CurrentTrack = null;
                Suggestions = new();
            }
            PollSoftware();
        }

        private void UpdateCurrentTrackFromSelection()
        {
            Track? selected = null;

            if (ActiveDeckSelection == "1")
            {
                selected = Deck1Track;
            }
            else if (ActiveDeckSelection == "2")
            {
                selected = Deck2Track;
            }
            else // "AUTO"
            {
                // Sélectionne la platine active la plus récente
                if (Deck1Track != null && Deck2Track != null)
                {
                    int id1 = Deck1Track.HistoryEntryId ?? 0;
                    int id2 = Deck2Track.HistoryEntryId ?? 0;
                    selected = id1 >= id2 ? Deck1Track : Deck2Track;
                }
                else
                {
                    selected = Deck1Track ?? Deck2Track;
                }
            }

            bool trackChanged = false;
            if (CurrentTrack == null && selected != null) trackChanged = true;
            else if (CurrentTrack != null && selected == null) trackChanged = true;
            else if (CurrentTrack != null && selected != null &&
                     (CurrentTrack.DisplayTitle != selected.DisplayTitle || CurrentTrack.DisplayArtist != selected.DisplayArtist))
            {
                trackChanged = true;
            }

            if (trackChanged)
            {
                CurrentTrack = selected;
                RefreshSuggestions();
            }
        }

        public void RefreshSuggestions()
        {
            if (CurrentTrack == null)
            {
                Suggestions = new();
                return;
            }

            var settings = UserSettings.Shared;

            if (ActiveDJSoftware == "rekordbox")
            {
                var (routines, favs, harmonic) = RekordboxService.Shared.FindNextSuggestions(
                    CurrentTrack,
                    settings.MaxSuggestions,
                    settings.MinTransitionsCount,
                    settings.BpmTolerancePercent,
                    settings.IsHarmonicFilterActive,
                    settings.IsBpmFilterActive,
                    settings.IsFavoritesFilterActive
                );

                _historySuggestions = routines;
                _favoriteSuggestions = favs;

                if (settings.IsFavoritesFilterActive)
                {
                    Suggestions = favs;
                }
                else
                {
                    var combined = new List<Track>(routines);
                    var ids = new HashSet<string>(combined.Select(t => t.Id));
                    foreach (var h in harmonic)
                    {
                        if (!ids.Contains(h.Id))
                        {
                            combined.Add(h);
                            if (combined.Count >= settings.MaxSuggestions) break;
                        }
                    }
                    Suggestions = combined;
                }
                return;
            }

            // 1. Récupération de l'historique Serato
            _historySuggestions = _dbService.FetchRoutineTransitions(CurrentTrack, settings.HistoryDaysLookback, settings.MaxSuggestions);

            // 2. Récupération des favoris manuels
            _favoriteSuggestions = FavoriteCombosService.Shared.GetFavoriteSuggestionsFor(CurrentTrack);

            UpdateFilteredSuggestions();
        }

        public void UpdateFilteredSuggestions()
        {
            var settings = UserSettings.Shared;
            List<Track> list;

            if (settings.IsFavoritesFilterActive)
            {
                list = _favoriteSuggestions.ToList();
            }
            else
            {
                var combined = _historySuggestions.ToList();
                foreach (var fav in _favoriteSuggestions)
                {
                    string normFav = FavoriteCombosService.Normalize(fav.DisplayTitle);
                    var existing = combined.FirstOrDefault(t =>
                        FavoriteCombosService.Normalize(t.DisplayTitle) == normFav ||
                        (!string.IsNullOrEmpty(fav.FileName) && !string.IsNullOrEmpty(t.FileName) && FavoriteCombosService.Normalize(t.FileName) == FavoriteCombosService.Normalize(fav.FileName))
                    );

                    if (existing != null)
                    {
                        existing.IsFavorite = true;
                    }
                    else
                    {
                        combined.Add(fav);
                    }
                }

                double GetRankingScore(Track trk)
                {
                    if (trk.TransitionCount >= 2)
                        return trk.TransitionCount + (trk.IsFavorite ? 0.05 : 0.0);
                    if (trk.IsFavorite)
                        return trk.TransitionCount == 1 ? 1.55 : 1.50;
                    if (trk.TransitionCount == 1)
                        return 1.0;
                    return 0.0;
                }

                list = combined.OrderByDescending(GetRankingScore)
                               .ThenByDescending(t => t.PlayedAt)
                               .ThenBy(t => t.DisplayTitle)
                               .ToList();
            }

            // Filtre Harmonique
            if (settings.IsHarmonicFilterActive)
            {
                list = list.Where(t => t.HarmonicRelation?.IsCompatible() == true).ToList();
            }

            // Filtre BPM (tolérance directe, half-time, double-time)
            if (settings.IsBpmFilterActive && CurrentTrack != null && CurrentTrack.Bpm > 0)
            {
                double currentBpm = CurrentTrack.Bpm;
                double tol = settings.BpmTolerancePercent / 100.0;

                list = list.Where(t =>
                {
                    if (t.Bpm <= 0) return false;
                    double r1 = t.Bpm / currentBpm;
                    if (Math.Abs(r1 - 1.0) <= tol) return true;

                    double r2 = (t.Bpm / 2.0) / currentBpm;
                    if (Math.Abs(r2 - 1.0) <= tol) return true;

                    double r3 = (t.Bpm * 2.0) / currentBpm;
                    if (Math.Abs(r3 - 1.0) <= tol) return true;

                    return false;
                }).ToList();
            }

            // Marquage ou masquage des morceaux déjà joués
            foreach (var track in list)
            {
                track.IsPlayedInSession = _playedTitlesInSession.Contains(track.DisplayTitle);
                track.IsFavorite = FavoriteCombosService.Shared.IsComboFavorite(CurrentTrack!, track);
            }

            if (settings.HidePlayedTracks)
            {
                list = list.Where(t => !t.IsPlayedInSession).ToList();
            }

            Suggestions = list;
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
