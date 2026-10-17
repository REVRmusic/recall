using System;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Recall.Services;

namespace Recall
{
    public partial class SetRecapWindow : Window
    {
        private readonly SessionHistoryService _history = SessionHistoryService.Shared;
        private readonly DispatcherTimer _timer;

        public SetRecapWindow()
        {
            InitializeComponent();
            _timer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(1)
            };
            _timer.Tick += (s, e) =>
            {
                // OPTIMISATION CPU : si aucun morceau ne joue, stopper le rafraîchissement récurrent
                if (!_history.IsCurrentlyPlaying) return;
                UpdateStatsUI();
            };
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            _history.PropertyChanged += History_PropertyChanged;
            _history.SyncWithDatabase();
            UpdateStatsUI();
            _timer.Start();
        }

        private void History_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(SessionHistoryService.PlayedTracks) || e.PropertyName == nameof(SessionHistoryService.IsCurrentlyPlaying))
            {
                Dispatcher.Invoke(UpdateStatsUI);
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            base.OnClosed(e);
            _history.PropertyChanged -= History_PropertyChanged;
            _timer.Stop();
        }

        private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ButtonState == MouseButtonState.Pressed)
            {
                try { DragMove(); } catch { }
            }
        }

        private void Header_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ButtonState == MouseButtonState.Pressed)
            {
                try { DragMove(); } catch { }
            }
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }

        private void UpdateStatsUI()
        {
            var stats = _history.ComputeCurrentStats();

            if (stats.TotalTracksCount == 0)
            {
                DotStatus.Fill = new SolidColorBrush(Color.FromArgb(76, 255, 255, 255));
                TxtSessionStatus.Text = "Mix non démarré (en attente du 1er morceau)";
                TxtTotalDuration.Text = "00m 00s";
                TxtTotalTracks.Text = "0";
                TxtAvgTimePerTrack.Text = "--";
                TxtPacing.Text = "En attente";
                TxtAvgBpm.Text = "-- BPM";
                TxtBpmRange.Text = "Plage : --";
                TxtDominantKey.Text = "--";
                TxtDominantKeyInfo.Text = "En attente";
                TxtDominantGenre.Text = "--";
                TxtDominantGenreInfo.Text = "En attente";
                TxtTracksPerHour.Text = "--";

                TxtTopGenreBadge.Text = "";
                PanelTopGenres.Children.Clear();
                PanelTopGenres.Children.Add(new TextBlock { Text = "Genres musicaux en cours d'analyse...", FontSize = 9.5, Foreground = new SolidColorBrush(Color.FromRgb(107, 114, 128)), Margin = new Thickness(0, 4, 0, 4) });

                TxtTopArtistBadge.Text = "";
                PanelTopArtists.Children.Clear();
                PanelTopArtists.Children.Add(new TextBlock { Text = "Artistes en cours d'analyse...", FontSize = 9.5, Foreground = new SolidColorBrush(Color.FromRgb(107, 114, 128)), Margin = new Thickness(0, 4, 0, 4) });
                return;
            }

            if (stats.IsLiveSession)
            {
                DotStatus.Fill = new SolidColorBrush(Color.FromRgb(34, 197, 94));
                TxtSessionStatus.Text = "Session en direct";
            }
            else
            {
                DotStatus.Fill = new SolidColorBrush(Color.FromRgb(249, 115, 22));
                TxtSessionStatus.Text = "En pause";
            }
            TxtTotalDuration.Text = FormatDuration(stats.TotalDurationSeconds);
            TxtTotalTracks.Text = stats.TotalTracksCount.ToString();
            TxtAvgTimePerTrack.Text = FormatMinutesSeconds(stats.AverageTimePerTrackSeconds);

            // Pacing
            if (stats.TotalTracksCount >= 2)
            {
                if (stats.AverageTimePerTrackSeconds < 90)
                {
                    TxtPacing.Text = "⚡ Quick Mix";
                    BadgePacing.Background = new SolidColorBrush(Color.FromArgb(50, 255, 159, 67));
                    TxtPacing.Foreground = new SolidColorBrush(Color.FromRgb(255, 159, 67));
                }
                else if (stats.AverageTimePerTrackSeconds < 180)
                {
                    TxtPacing.Text = "🔥 Dynamique";
                    BadgePacing.Background = new SolidColorBrush(Color.FromArgb(50, 255, 82, 82));
                    TxtPacing.Foreground = new SolidColorBrush(Color.FromRgb(255, 82, 82));
                }
                else if (stats.AverageTimePerTrackSeconds < 300)
                {
                    TxtPacing.Text = "🌊 Progressif";
                    BadgePacing.Background = new SolidColorBrush(Color.FromArgb(50, 20, 200, 176));
                    TxtPacing.Foreground = new SolidColorBrush(Color.FromRgb(20, 200, 176));
                }
                else
                {
                    TxtPacing.Text = "🧘 Deep / Long Blend";
                    BadgePacing.Background = new SolidColorBrush(Color.FromArgb(50, 196, 113, 237));
                    TxtPacing.Foreground = new SolidColorBrush(Color.FromRgb(196, 113, 237));
                }
            }
            else
            {
                TxtPacing.Text = "1 seul morceau";
            }

            // BPM
            TxtAvgBpm.Text = stats.AverageBpm > 0 ? $"{stats.AverageBpm:F1} BPM" : "-- BPM";
            TxtBpmRange.Text = stats.MinBpm > 0 ? $"Plage : {(int)Math.Round(stats.MinBpm)} - {(int)Math.Round(stats.MaxBpm)} BPM" : "Aucun BPM";

            // Clé dominante
            TxtDominantKey.Text = stats.DominantKey ?? "--";
            TxtDominantKeyInfo.Text = stats.DominantKey != null ? $"{stats.DominantKeyCount} tracks ({(int)Math.Round(stats.DominantKeyPercentage)}% du set)" : "Clés non analysées";

            // Genre dominant (User Request #1)
            if (stats.MostPlayedGenre != null)
            {
                TxtDominantGenre.Text = stats.MostPlayedGenre.Name;
                TxtDominantGenreInfo.Text = $"{stats.MostPlayedGenre.Count} tracks ({(int)Math.Round(stats.MostPlayedGenre.Percent)}% du set)";
                TxtTopGenreBadge.Text = $"Top 1 : {stats.MostPlayedGenre.Name}";
            }
            else
            {
                TxtDominantGenre.Text = "--";
                TxtDominantGenreInfo.Text = "En attente des genres";
                TxtTopGenreBadge.Text = "";
            }

            TxtTracksPerHour.Text = $"{stats.TracksPerHour:F1} tracks/h";

            // Render Top Genres
            PanelTopGenres.Children.Clear();
            if (stats.TopGenres.Count == 0)
            {
                PanelTopGenres.Children.Add(new TextBlock { Text = "Aucun genre récurrent détecté dans la session.", FontSize = 9.5, Foreground = new SolidColorBrush(Color.FromRgb(107, 114, 128)), Margin = new Thickness(0, 4, 0, 4) });
            }
            else
            {
                int index = 1;
                foreach (var g in stats.TopGenres)
                {
                    PanelTopGenres.Children.Add(CreateRankedRow(index++, g.Name, g.Count, g.Percent, Color.FromRgb(20, 200, 176)));
                }
            }

            // Render Top Artists
            PanelTopArtists.Children.Clear();
            if (stats.TopArtists.Count == 0)
            {
                PanelTopArtists.Children.Add(new TextBlock { Text = "Aucun artiste récurrent détecté dans la session.", FontSize = 9.5, Foreground = new SolidColorBrush(Color.FromRgb(107, 114, 128)), Margin = new Thickness(0, 4, 0, 4) });
            }
            else
            {
                TxtTopArtistBadge.Text = stats.MostPlayedArtist != null ? $"Top 1 : {stats.MostPlayedArtist.Name}" : "";
                int index = 1;
                foreach (var a in stats.TopArtists)
                {
                    PanelTopArtists.Children.Add(CreateRankedRow(index++, a.Name, a.Count, a.Percent, Color.FromRgb(255, 215, 0)));
                }
            }
        }

        private UIElement CreateRankedRow(int rank, string name, int count, double percent, Color accentColor)
        {
            var border = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(10, 255, 255, 255)),
                CornerRadius = new CornerRadius(5),
                Padding = new Thickness(8, 4, 8, 4),
                Margin = new Thickness(0, 2, 0, 2)
            };

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(20) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(70) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(55) });

            var txtRank = new TextBlock
            {
                Text = $"{rank}.",
                FontWeight = FontWeights.Bold,
                FontSize = 10,
                Foreground = rank == 1 ? new SolidColorBrush(accentColor) : new SolidColorBrush(Color.FromRgb(156, 163, 175)),
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(txtRank, 0);
            grid.Children.Add(txtRank);

            var txtName = new TextBlock
            {
                Text = name,
                FontSize = 10.5,
                FontWeight = FontWeights.Medium,
                Foreground = Brushes.White,
                TextTrimming = TextTrimming.CharacterEllipsis,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(txtName, 1);
            grid.Children.Add(txtName);

            // Progress bar
            var barBg = new Border
            {
                Background = new SolidColorBrush(Color.FromArgb(20, 255, 255, 255)),
                CornerRadius = new CornerRadius(2),
                Height = 4,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(4, 0, 4, 0)
            };
            var barFill = new Border
            {
                Background = rank == 1 ? new SolidColorBrush(accentColor) : new SolidColorBrush(Color.FromArgb(200, 196, 113, 237)),
                CornerRadius = new CornerRadius(2),
                Height = 4,
                HorizontalAlignment = HorizontalAlignment.Left,
                Width = Math.Max(4, Math.Min(60, (percent / 100.0) * 60.0))
            };
            var barContainer = new Grid { VerticalAlignment = VerticalAlignment.Center };
            barContainer.Children.Add(barBg);
            barContainer.Children.Add(barFill);
            Grid.SetColumn(barContainer, 2);
            grid.Children.Add(barContainer);

            var txtCount = new TextBlock
            {
                Text = $"{count} track{(count > 1 ? "s" : "")}",
                FontSize = 9.5,
                FontWeight = FontWeights.Bold,
                Foreground = new SolidColorBrush(accentColor),
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(txtCount, 3);
            grid.Children.Add(txtCount);

            border.Child = grid;
            return border;
        }

        private static string FormatDuration(double seconds)
        {
            if (seconds <= 0) return "00m 00s";
            var ts = TimeSpan.FromSeconds(seconds);
            if (ts.TotalHours >= 1)
            {
                return $"{(int)ts.TotalHours}h {ts.Minutes:D2}m {ts.Seconds:D2}s";
            }
            return $"{ts.Minutes:D2}m {ts.Seconds:D2}s";
        }

        private static string FormatMinutesSeconds(double seconds)
        {
            if (seconds <= 0) return "--";
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{ts.Minutes}m {ts.Seconds:D2}s";
        }

        private void BtnResetSession_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(this, "Démarrer un nouveau mix et réinitialiser les statistiques du set en cours ?", "Nouveau Set", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (res == MessageBoxResult.Yes)
            {
                _history.ResetSession();
                UpdateStatsUI();
            }
        }

        private void BtnCopySummary_Click(object sender, RoutedEventArgs e)
        {
            var stats = _history.ComputeCurrentStats();
            var sb = new StringBuilder();
            sb.AppendLine("🎧 RECALL - SET RECAP");
            sb.AppendLine($"⏱ Durée totale : {FormatDuration(stats.TotalDurationSeconds)}");
            sb.AppendLine($"🎵 Morceaux joués : {stats.TotalTracksCount}");
            sb.AppendLine($"⚡ Cadence : {stats.TracksPerHour:F1} tracks/h ({FormatMinutesSeconds(stats.AverageTimePerTrackSeconds)}/track)");
            if (stats.AverageBpm > 0) sb.AppendLine($"⏱ BPM moyen : {stats.AverageBpm:F1} (Plage: {(int)stats.MinBpm}-{(int)stats.MaxBpm})");
            if (!string.IsNullOrEmpty(stats.DominantKey)) sb.AppendLine($"🎹 Tonalité dominante : {stats.DominantKey} ({stats.DominantKeyCount} tracks - {(int)Math.Round(stats.DominantKeyPercentage)}%)");
            if (stats.MostPlayedGenre != null) sb.AppendLine($"🎧 Genre le plus joué : {stats.MostPlayedGenre.Name} ({stats.MostPlayedGenre.Count} tracks - {(int)Math.Round(stats.MostPlayedGenre.Percent)}%)");
            if (stats.TopGenres != null && stats.TopGenres.Count > 0)
            {
                var genresStr = string.Join(", ", stats.TopGenres.Select(g => $"{g.Name} ({g.Count})"));
                sb.AppendLine($"🎷 Top Genres : {genresStr}");
            }
            if (stats.MostPlayedArtist != null) sb.AppendLine($"👑 Artiste le plus joué : {stats.MostPlayedArtist.Name} ({stats.MostPlayedArtist.Count} tracks)");
            sb.AppendLine("\n────────────────────────");
            sb.AppendLine("⚡ Compagnon DJ intelligent Recall (mixify.fr)");

            try
            {
                Clipboard.SetText(sb.ToString());
                MessageBox.Show(this, "Résumé du mix copié dans le presse-papiers !", "Copié", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch { }
        }
    }
}
