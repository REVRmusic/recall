using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Recall.Models;
using Recall.Services;

namespace Recall
{
    public partial class MainWindow : Window
    {
        private readonly SeratoMonitorService _monitor = SeratoMonitorService.Shared;
        private readonly SessionHistoryService _history = SessionHistoryService.Shared;
        private readonly UserSettings _settings = UserSettings.Shared;

        private const double MinNormalHeight = 227.0;
        private const double CompactHeight = 54.0;
        private const double MinCompactWidth = 300.0;
        private const double DefaultCompactWidth = 360.0;
        private const double MinNormalWidth = 300.0;
        private const double DefaultNormalWidth = 360.0;
        private double _lastNormalHeight = 530.0;
        private double _lastNormalWidth = 360.0;

        public MainWindow()
        {
            InitializeComponent();
            _monitor.PropertyChanged += Monitor_PropertyChanged;
            _history.PropertyChanged += History_PropertyChanged;
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            ApplySettingsToUI();
            PositionAtBottomRight();
            UpdateUI();
        }

        public void PositionAtBottomRight()
        {
            var workArea = SystemParameters.WorkArea;
            Left = workArea.Right - Width;
            Top = workArea.Bottom - Height;
        }

        private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            // Empêche le comportement système de maximisation ou recentrage lors d'un double-clic
            if (e.ClickCount >= 2)
            {
                e.Handled = true;
                return;
            }

            if (e.ButtonState == MouseButtonState.Pressed)
            {
                DragMove();
                ClampToScreen();
            }
        }

        private void ClampToScreen()
        {
            var workArea = SystemParameters.WorkArea;
            if (Left < workArea.Left) Left = workArea.Left;
            if (Left + Width > workArea.Right) Left = workArea.Right - Width;
            if (Top < workArea.Top) Top = workArea.Top;
            if (Top + Height > workArea.Bottom) Top = workArea.Bottom - Height;
        }

        private void Window_KeyDown(object sender, KeyEventArgs e)
        {
            if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control &&
                (Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift)
            {
                if (e.Key == Key.F)
                {
                    BtnSearch_Click(sender, e);
                    e.Handled = true;
                }
                else if (e.Key == Key.S)
                {
                    BtnStats_Click(sender, e);
                    e.Handled = true;
                }
                else if (e.Key == Key.C)
                {
                    SetCompactMode(!_settings.IsCompactMode);
                    e.Handled = true;
                }
            }
        }

        private void Monitor_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            Dispatcher.Invoke(UpdateUI);
        }

        private void History_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            Dispatcher.Invoke(UpdateUI);
        }

        private void UpdateUI()
        {
            TxtSessionCount.Text = _history.PlayedCount.ToString();

            // Morceau en cours
            var current = _monitor.CurrentTrack;
            if (current != null)
            {
                DotNowStatus.Fill = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                TxtNowStatus.Text = "EN COURS";
                TxtNowStatus.Foreground = new SolidColorBrush(Color.FromRgb(20, 200, 176));

                TxtNowTitle.Text = current.DisplayTitle;
                TxtNowArtist.Text = current.DisplayArtist;
                TxtNowKey.Text = current.DisplayKey;
                TxtNowBpm.Text = $"{current.DisplayBpm} BPM";

                if (current.CamelotKey != null)
                {
                    try
                    {
                        var color = (Color)ColorConverter.ConvertFromString(current.CamelotKey.ColorHex);
                        BadgeNowKey.BorderBrush = new SolidColorBrush(color);
                        TxtNowKey.Foreground = new SolidColorBrush(color);
                        VinylMacaron.Background = new SolidColorBrush(color);
                    }
                    catch
                    {
                        BadgeNowKey.BorderBrush = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                        TxtNowKey.Foreground = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                        VinylMacaron.Background = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                    }
                }
                else
                {
                    BadgeNowKey.BorderBrush = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                    TxtNowKey.Foreground = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                    VinylMacaron.Background = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                }

                // Vérifier si la combinaison actuelle est déjà en favori
                bool isFavoriteCombo = false;
                if (_monitor.Deck1Track != null && _monitor.Deck2Track != null)
                {
                    isFavoriteCombo = FavoriteCombosService.Shared.IsComboFavorite(_monitor.Deck1Track, _monitor.Deck2Track);
                }

                TxtSaveComboIcon.Text = isFavoriteCombo ? "♥ " : "♡ ";
                TxtSaveComboLabel.Text = isFavoriteCombo ? "Combo en favoris" : "Sauvegarder ce combo";
                BtnSaveCombo.Visibility = Visibility.Visible;
            }
            else
            {
                DotNowStatus.Fill = new SolidColorBrush(Color.FromRgb(156, 163, 175));
                TxtNowStatus.Text = "EN ATTENTE";
                TxtNowStatus.Foreground = new SolidColorBrush(Color.FromRgb(156, 163, 175));

                if (_monitor.ActiveDJSoftware == "rekordbox")
                {
                    TxtNowTitle.Text = _monitor.IsRekordboxConnected ? "Aucun morceau en lecture" : "En attente de Rekordbox...";
                    TxtNowArtist.Text = _monitor.IsRekordboxConnected ? "Lancez un morceau dans Rekordbox" : "Ouvrez Pioneer DJ Rekordbox pour démarrer";
                }
                else
                {
                    TxtNowTitle.Text = _monitor.IsSeratoConnected ? "Platines en attente" : "En attente de Serato DJ Pro...";
                    TxtNowArtist.Text = _monitor.IsSeratoConnected ? "Lancez un morceau sur Deck 1 ou 2" : "Ouvrez Serato DJ Pro pour démarrer";
                }

                TxtNowKey.Text = "--";
                TxtNowBpm.Text = "-- BPM";
                BadgeNowKey.BorderBrush = new SolidColorBrush(Color.FromRgb(55, 65, 81));
                TxtNowKey.Foreground = new SolidColorBrush(Color.FromRgb(156, 163, 175));
                VinylMacaron.Background = new SolidColorBrush(Color.FromRgb(55, 65, 81));
                BtnSaveCombo.Visibility = Visibility.Collapsed;
            }

            if (_settings.IsToPlayFilterActive)
            {
                var toPlayList = ToPlayService.Shared.ToTrackList(_monitor.CurrentTrack);
                if (_settings.IsHarmonicFilterActive && _monitor.CurrentTrack?.CamelotKey != null)
                {
                    toPlayList = toPlayList.Where(t => t.HarmonicRelation.HasValue && t.HarmonicRelation.Value.IsCompatible()).ToList();
                }
                if (_settings.IsBpmFilterActive && _monitor.CurrentTrack?.Bpm > 0)
                {
                    double currentBpm = _monitor.CurrentTrack.Bpm;
                    double tol = _settings.BpmTolerancePercent / 100.0;
                    toPlayList = toPlayList.Where(t => t.Bpm > 0 && Math.Abs(t.Bpm / currentBpm - 1.0) <= tol).ToList();
                }

                ListSuggestions.ItemsSource = toPlayList;
                TxtMatchCount.Text = $"{toPlayList.Count} sélec";
                ChkFilterToPlay.Content = toPlayList.Count > 0 ? $"★ Sélec ({toPlayList.Count})" : "★ Sélec";

                var topToPlay = toPlayList.FirstOrDefault();
                if (topToPlay != null)
                {
                    TxtCompactTitle.Text = topToPlay.DisplayTitle;
                    TxtCompactArtist.Text = topToPlay.DisplayArtist;
                    TxtCompactKey.Text = topToPlay.DisplayKey;
                    TxtCompactBpm.Text = $"{topToPlay.DisplayBpm} BPM";
                }
                else
                {
                    TxtCompactTitle.Text = "Aucun morceau en sélec";
                    TxtCompactArtist.Text = "Glissez un morceau ici";
                    TxtCompactKey.Text = "--";
                    TxtCompactBpm.Text = "-- BPM";
                }
            }
            else
            {
                // Liste des suggestions
                ListSuggestions.ItemsSource = _monitor.Suggestions;
                TxtMatchCount.Text = $"{_monitor.Suggestions.Count} match{(_monitor.Suggestions.Count > 1 ? "s" : "")}";
                int toPlayTotal = ToPlayService.Shared.GetTracks().Count;
                ChkFilterToPlay.Content = toPlayTotal > 0 ? $"★ Sélec ({toPlayTotal})" : "★ Sélec";

                // Vue compacte
                var topSuggestion = _monitor.Suggestions.FirstOrDefault();
                if (topSuggestion != null)
                {
                    TxtCompactTitle.Text = topSuggestion.DisplayTitle;
                    TxtCompactArtist.Text = topSuggestion.DisplayArtist;
                    TxtCompactKey.Text = topSuggestion.DisplayKey;
                    TxtCompactBpm.Text = $"{topSuggestion.DisplayBpm} BPM";
                }
                else
                {
                    TxtCompactTitle.Text = current != null ? current.DisplayTitle : "Aucune suggestion";
                    TxtCompactArtist.Text = current != null ? current.DisplayArtist : "En attente...";
                    TxtCompactKey.Text = current?.DisplayKey ?? "--";
                    TxtCompactBpm.Text = current != null ? $"{current.DisplayBpm} BPM" : "-- BPM";
                }
            }

            // Always On Top Pin
            BtnPin.Foreground = new SolidColorBrush(_settings.AlwaysOnTop ? Color.FromRgb(20, 200, 176) : Color.FromRgb(156, 163, 175));
        }

        private void ApplySettingsToUI()
        {
            Topmost = _settings.AlwaysOnTop;
            ChkFilterBpm.IsChecked = _settings.IsBpmFilterActive;
            ChkFilterHarmonie.IsChecked = _settings.IsHarmonicFilterActive;
            ChkFilterFavs.IsChecked = _settings.IsFavoritesFilterActive;
            ChkFilterToPlay.IsChecked = _settings.IsToPlayFilterActive;

            if (_settings.IsCompactMode)
            {
                SetCompactMode(true);
            }
        }

        private void SetCompactMode(bool compact)
        {
            _settings.IsCompactMode = compact;
            _settings.Save();

            var workArea = SystemParameters.WorkArea;

            if (compact)
            {
                if (Height >= MinNormalHeight) _lastNormalHeight = Height;
                if (Width >= MinNormalWidth) _lastNormalWidth = Width;
                NormalViewGrid.Visibility = Visibility.Collapsed;
                CompactViewGrid.Visibility = Visibility.Visible;
                Height = CompactHeight;
                MinWidth = MinCompactWidth;
                Width = Math.Max(MinCompactWidth, Width >= MinCompactWidth ? Width : DefaultCompactWidth);
            }
            else
            {
                CompactViewGrid.Visibility = Visibility.Collapsed;
                NormalViewGrid.Visibility = Visibility.Visible;
                Height = Math.Max(MinNormalHeight, _lastNormalHeight);
                MinWidth = MinNormalWidth;
                Width = Math.Max(MinNormalWidth, _lastNormalWidth);
            }

            // Toujours calé en bas à droite
            Left = workArea.Right - Width;
            Top = workArea.Bottom - Height;
        }

        private void BtnCollapse_Click(object sender, RoutedEventArgs e) => SetCompactMode(true);
        private void BtnExpand_Click(object sender, RoutedEventArgs e) => SetCompactMode(false);
        private void BtnClose_Click(object sender, RoutedEventArgs e) => Close();

        private void BtnSearch_Click(object sender, RoutedEventArgs e)
        {
            var searchWnd = new SearchWindow { Owner = this };
            searchWnd.ShowDialog();
            UpdateUI();
        }

        private void BtnStats_Click(object sender, RoutedEventArgs e)
        {
            var statsWnd = new SetRecapWindow { Owner = this };
            statsWnd.ShowDialog();
            UpdateUI();
        }

        private void BtnGuide_Click(object sender, RoutedEventArgs e)
        {
            var guideWnd = new GuideWindow { Owner = this };
            guideWnd.ShowDialog();
        }

        private void BtnPin_Click(object sender, RoutedEventArgs e)
        {
            _settings.AlwaysOnTop = !_settings.AlwaysOnTop;
            _settings.Save();
            Topmost = _settings.AlwaysOnTop;
            BtnPin.Foreground = new SolidColorBrush(_settings.AlwaysOnTop ? Color.FromRgb(20, 200, 176) : Color.FromRgb(156, 163, 175));
        }

        private void BtnSettings_Click(object sender, RoutedEventArgs e)
        {
            var settingsWnd = new SettingsWindow { Owner = this };
            settingsWnd.ShowDialog();
            ApplySettingsToUI();
            _monitor.RefreshSuggestions();
        }

        private void BtnSessionReset_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(this, "Démarrer un nouveau mix et réinitialiser les statistiques du set ?", "Nouveau Set Recall", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (res == MessageBoxResult.Yes)
            {
                _history.ResetSession();
                _monitor.RefreshSuggestions();
                UpdateUI();
            }
        }

        private void BtnSessionReset_RightClick(object sender, MouseButtonEventArgs e)
        {
            BtnStats_Click(sender, e);
        }

        private void BtnClearManual_Click(object sender, RoutedEventArgs e)
        {
            _monitor.ClearManualOverride();
            BtnClearManual.Visibility = Visibility.Collapsed;
            UpdateUI();
        }

        private void DeckRadio_Checked(object sender, RoutedEventArgs e)
        {
            if (RbAuto.IsChecked == true) _monitor.ActiveDeckSelection = "AUTO";
            else if (RbDeck1.IsChecked == true) _monitor.ActiveDeckSelection = "1";
            else if (RbDeck2.IsChecked == true) _monitor.ActiveDeckSelection = "2";
        }

        private void FilterChanged(object sender, RoutedEventArgs e)
        {
            if (sender == ChkFilterToPlay)
            {
                _settings.IsToPlayFilterActive = ChkFilterToPlay.IsChecked == true;
                if (_settings.IsToPlayFilterActive)
                {
                    _settings.IsFavoritesFilterActive = false;
                    ChkFilterFavs.IsChecked = false;
                }
            }
            else if (sender == ChkFilterFavs && ChkFilterFavs.IsChecked == true)
            {
                _settings.IsToPlayFilterActive = false;
                ChkFilterToPlay.IsChecked = false;
            }

            _settings.IsBpmFilterActive = ChkFilterBpm.IsChecked == true;
            _settings.IsHarmonicFilterActive = ChkFilterHarmonie.IsChecked == true;
            _settings.IsFavoritesFilterActive = ChkFilterFavs.IsChecked == true;
            _settings.IsToPlayFilterActive = ChkFilterToPlay.IsChecked == true;
            _settings.Save();

            if (_settings.IsToPlayFilterActive)
            {
                UpdateUI();
            }
            else
            {
                _monitor.UpdateFilteredSuggestions();
            }
        }

        private void BtnSaveCombo_Click(object sender, RoutedEventArgs e)
        {
            if (_monitor.Deck1Track != null && _monitor.Deck2Track != null)
            {
                FavoriteCombosService.Shared.ToggleCombo(_monitor.Deck1Track, _monitor.Deck2Track);
                UpdateUI();
            }
            else if (_monitor.CurrentTrack != null)
            {
                var top = _monitor.Suggestions.FirstOrDefault();
                if (top != null)
                {
                    FavoriteCombosService.Shared.ToggleCombo(_monitor.CurrentTrack, top);
                    UpdateUI();
                }
            }
        }

        private void ToggleFavorite_Click(object sender, RoutedEventArgs e)
        {
            if (ListSuggestions.SelectedItem is Track track && _monitor.CurrentTrack != null)
            {
                FavoriteCombosService.Shared.ToggleCombo(_monitor.CurrentTrack, track);
                _monitor.RefreshSuggestions();
                UpdateUI();
            }
        }

        private void OpenInExplorer_Click(object sender, RoutedEventArgs e)
        {
            if (ListSuggestions.SelectedItem is Track track && !string.IsNullOrEmpty(track.FilePath) && File.Exists(track.FilePath))
            {
                Process.Start("explorer.exe", $"/select,\"{track.FilePath}\"");
            }
        }

        // ==================== GLISSER-DÉPOSER NATIF VERS SERATO DJ PRO / REKORDBOX ====================
        private void ListSuggestions_PreviewMouseMove(object sender, MouseEventArgs e)
        {
            if (e.LeftButton == MouseButtonState.Pressed && sender is ListView lv && lv.SelectedItem is Track track)
            {
                if (!string.IsNullOrEmpty(track.FilePath) && File.Exists(track.FilePath))
                {
                    var data = new DataObject(DataFormats.FileDrop, new string[] { track.FilePath });
                    DragDrop.DoDragDrop(lv, data, DragDropEffects.Copy);
                }
            }
        }

        private void ListSuggestions_MouseDoubleClick(object sender, MouseButtonEventArgs e)
        {
            if (sender is ListView lv && lv.SelectedItem is Track track)
            {
                if (!string.IsNullOrEmpty(track.FilePath) && File.Exists(track.FilePath))
                {
                    Process.Start("explorer.exe", $"/select,\"{track.FilePath}\"");
                }
            }
        }

        // ==================== RÉCEPTION DU GLISSER-DÉPOSER DEPUIS SERATO / EXPLORATEUR ====================
        private void Window_DragEnter(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
                DropOverlay.Visibility = Visibility.Visible;
            }
            else
            {
                e.Effects = DragDropEffects.None;
            }
        }

        private void Window_DragLeave(object sender, DragEventArgs e)
        {
            DropOverlay.Visibility = Visibility.Collapsed;
        }

        private void Window_DragOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
            }
            else
            {
                e.Effects = DragDropEffects.None;
            }
            e.Handled = true;
        }

        private void Window_Drop(object sender, DragEventArgs e)
        {
            DropOverlay.Visibility = Visibility.Collapsed;
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                string[]? files = (string[])e.Data.GetData(DataFormats.FileDrop);
                if (files != null && files.Length > 0)
                {
                    foreach (var file in files)
                    {
                        ToPlayService.Shared.AddTrackFromPath(file);
                    }
                    _settings.IsToPlayFilterActive = true;
                    ChkFilterToPlay.IsChecked = true;
                    _settings.Save();
                    UpdateUI();
                }
            }
        }

        private void DeleteToPlay_Click(object sender, RoutedEventArgs e)
        {
            if (ListSuggestions.SelectedItem is Track track)
            {
                ToPlayService.Shared.RemoveTrack(track.Id);
                UpdateUI();
            }
        }
    }
}
