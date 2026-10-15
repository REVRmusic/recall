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
        private readonly UserSettings _settings = UserSettings.Shared;

        private const double MinNormalHeight = 227.0;
        private const double CompactHeight = 54.0;
        private double _lastNormalHeight = 530.0;

        public MainWindow()
        {
            InitializeComponent();
            _monitor.PropertyChanged += Monitor_PropertyChanged;
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

        private void Monitor_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            Dispatcher.Invoke(UpdateUI);
        }

        private void UpdateUI()
        {
            TxtSessionCount.Text = _monitor.PlayedCount.ToString();

            // Morceau en cours
            var current = _monitor.CurrentTrack;
            if (current != null)
            {
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
                    }
                    catch { }
                }

                BtnSaveCombo.Visibility = Visibility.Visible;
            }
            else
            {
                if (_monitor.ActiveDJSoftware == "rekordbox")
                {
                    TxtNowTitle.Text = _monitor.IsRekordboxConnected ? "Aucun morceau sélectionné" : "En attente de Rekordbox...";
                    TxtNowArtist.Text = _monitor.IsRekordboxConnected ? "Recherchez un morceau dans Rekordbox" : "Ouvrez Pioneer DJ Rekordbox pour démarrer";
                }
                else
                {
                    TxtNowTitle.Text = _monitor.IsSeratoConnected ? "Platine vide" : "En attente de Serato DJ Pro...";
                    TxtNowArtist.Text = _monitor.IsSeratoConnected ? "Chargez un morceau" : "Ouvrez Serato DJ Pro pour démarrer";
                }
                TxtNowKey.Text = "--";
                TxtNowBpm.Text = "-- BPM";
                BtnSaveCombo.Visibility = Visibility.Collapsed;
            }

            // Liste des suggestions
            ListSuggestions.ItemsSource = _monitor.Suggestions;
            TxtMatchCount.Text = $"{_monitor.Suggestions.Count} matchs";

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

        private void ApplySettingsToUI()
        {
            Topmost = _settings.AlwaysOnTop;
            ChkFilterBpm.IsChecked = _settings.IsBpmFilterActive;
            ChkFilterHarmonie.IsChecked = _settings.IsHarmonicFilterActive;
            ChkFilterFavs.IsChecked = _settings.IsFavoritesFilterActive;

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
                NormalViewGrid.Visibility = Visibility.Collapsed;
                CompactViewGrid.Visibility = Visibility.Visible;
                Height = CompactHeight;
            }
            else
            {
                CompactViewGrid.Visibility = Visibility.Collapsed;
                NormalViewGrid.Visibility = Visibility.Visible;
                Height = Math.Max(MinNormalHeight, _lastNormalHeight);
            }

            // Toujours calé en bas à droite
            Left = workArea.Right - Width;
            Top = workArea.Bottom - Height;
        }

        private void BtnCollapse_Click(object sender, RoutedEventArgs e) => SetCompactMode(true);
        private void BtnExpand_Click(object sender, RoutedEventArgs e) => SetCompactMode(false);
        private void BtnClose_Click(object sender, RoutedEventArgs e) => Close();

        private void BtnSettings_Click(object sender, RoutedEventArgs e)
        {
            var settingsWnd = new SettingsWindow { Owner = this };
            settingsWnd.ShowDialog();
            ApplySettingsToUI();
            _monitor.RefreshSuggestions();
        }

        private void DeckRadio_Checked(object sender, RoutedEventArgs e)
        {
            if (RbAuto.IsChecked == true) _monitor.ActiveDeckSelection = "AUTO";
            else if (RbDeck1.IsChecked == true) _monitor.ActiveDeckSelection = "1";
            else if (RbDeck2.IsChecked == true) _monitor.ActiveDeckSelection = "2";
        }

        private void FilterChanged(object sender, RoutedEventArgs e)
        {
            _settings.IsBpmFilterActive = ChkFilterBpm.IsChecked == true;
            _settings.IsHarmonicFilterActive = ChkFilterHarmonie.IsChecked == true;
            _settings.IsFavoritesFilterActive = ChkFilterFavs.IsChecked == true;
            _settings.Save();
            _monitor.UpdateFilteredSuggestions();
        }

        private void BtnSaveCombo_Click(object sender, RoutedEventArgs e)
        {
            if (_monitor.Deck1Track != null && _monitor.Deck2Track != null)
            {
                FavoriteCombosService.Shared.ToggleCombo(_monitor.Deck1Track, _monitor.Deck2Track);
                UpdateUI();
            }
        }

        // ==================== GLISSER-DÉPOSER NATIF VERS SERATO DJ PRO ====================
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
    }
}
