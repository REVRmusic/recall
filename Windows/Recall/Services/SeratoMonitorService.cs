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
            _timer.Tick += (s, e) => PollSerato();
            _timer.Start();

            // Premier polling immédiat
            PollSerato();
        }

        public void PollSerato()
        {
            var state = _dbService.FetchActiveDecks();
            IsSeratoConnected = state.HasActiveSession;
            Deck1Track = state.Deck1;
            Deck2Track = state.Deck2;

            _playedTitlesInSession = _dbService.FetchPlayedTrackTitlesInCurrentSession(UserSettings.Shared.PlayedMinDurationSeconds);
            PlayedCount = _playedTitlesInSession.Count;

            UpdateCurrentTrackFromSelection();
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

            // 1. Récupération de l'historique Serato
            _historySuggestions = _dbService.FetchRoutineTransitions(CurrentTrack, settings.HistoryDaysLookback, settings.MaxSuggestions);

            // 2. Récupération des favoris manuels
            _favoriteSuggestions = FavoriteCombosService.Shared.GetFavoriteSuggestionsFor(CurrentTrack);

            UpdateFilteredSuggestions();
        }

        public void UpdateFilteredSuggestions()
        {
            var settings = UserSettings.Shared;
            var list = settings.IsFavoritesFilterActive ? _favoriteSuggestions : _historySuggestions;

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
