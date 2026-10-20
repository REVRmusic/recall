using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using Recall.Models;
using Recall.Services;

namespace Recall
{
    public partial class TracklistGeneratorWindow : Window
    {
        private readonly SessionHistoryService _history = SessionHistoryService.Shared;
        private readonly ToPlayService _toPlay = ToPlayService.Shared;

        public TracklistGeneratorWindow()
        {
            InitializeComponent();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            GenerateTracklist();
        }

        private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
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

        private void Format_Changed(object sender, SelectionChangedEventArgs e)
        {
            if (!IsLoaded) return;

            string tag = (CmbFormat.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "youtube";
            switch (tag)
            {
                case "youtube":
                    ChkTimestamps.IsChecked = true;
                    ChkNumbering.IsChecked = false;
                    ChkBpmKey.IsChecked = false;
                    break;
                case "tracklist1001":
                    ChkTimestamps.IsChecked = true;
                    ChkNumbering.IsChecked = true;
                    ChkBpmKey.IsChecked = false;
                    break;
                case "social":
                    ChkTimestamps.IsChecked = false;
                    ChkNumbering.IsChecked = true;
                    ChkBpmKey.IsChecked = false;
                    break;
                case "liveTimestamp":
                    ChkTimestamps.IsChecked = true;
                    ChkNumbering.IsChecked = false;
                    ChkBpmKey.IsChecked = false;
                    break;
                case "detailedDJ":
                    ChkTimestamps.IsChecked = true;
                    ChkNumbering.IsChecked = true;
                    ChkBpmKey.IsChecked = true;
                    break;
                case "m3u8":
                    ChkTimestamps.IsChecked = false;
                    ChkNumbering.IsChecked = false;
                    ChkBpmKey.IsChecked = false;
                    break;
            }

            GenerateTracklist();
        }

        private void Options_Changed(object sender, RoutedEventArgs e)
        {
            if (!IsLoaded) return;
            GenerateTracklist();
        }

        private void GenerateTracklist()
        {
            string sourceTag = (CmbSource.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "session";
            string formatTag = (CmbFormat.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "youtube";

            var tracks = new List<Track>();

            if (sourceTag == "session")
            {
                tracks.AddRange(_history.PlayedTracks);
            }
            else
            {
                tracks.AddRange(_toPlay.ToTrackList());
            }

            if (tracks.Count == 0)
            {
                TxtTracklist.Text = "// Aucun morceau enregistré pour le moment.\n// Jouez des morceaux dans Serato / Rekordbox ou ajoutez des titres à votre sélec 'À jouer'.";
                TxtTrackCount.Text = "0 morceau";
                return;
            }

            if (ChkChronological.IsChecked == false)
            {
                tracks.Reverse();
            }

            TxtTrackCount.Text = $"{tracks.Count} morceau{(tracks.Count > 1 ? "x" : "")}";

            if (formatTag == "m3u8")
            {
                TxtTracklist.Text = GenerateM3U8(tracks);
                return;
            }

            bool timestamps = ChkTimestamps.IsChecked == true;
            bool numbering = ChkNumbering.IsChecked == true;
            bool bpmKey = ChkBpmKey.IsChecked == true;
            bool artistFirst = ChkArtistFirst.IsChecked == true;

            var sb = new StringBuilder();
            DateTime? firstPlayed = tracks.FirstOrDefault(t => t.PlayedAt.HasValue)?.PlayedAt;
            double elapsedRunningSeconds = 0;

            for (int i = 0; i < tracks.Count; i++)
            {
                var track = tracks[i];
                var parts = new List<string>();

                // 1. Numérotation
                if (numbering)
                {
                    parts.Add($"{(i + 1):D2}.");
                }

                // 2. Horodatage
                if (timestamps)
                {
                    if (formatTag == "liveTimestamp" && track.PlayedAt.HasValue)
                    {
                        parts.Add($"[{track.PlayedAt.Value:HH:mm}]");
                    }
                    else if (firstPlayed.HasValue && track.PlayedAt.HasValue && track.PlayedAt.Value >= firstPlayed.Value)
                    {
                        var diff = track.PlayedAt.Value - firstPlayed.Value;
                        parts.Add(FormatTimecode(diff.TotalSeconds));
                    }
                    else
                    {
                        parts.Add(FormatTimecode(elapsedRunningSeconds));
                        elapsedRunningSeconds += 180; // estimation 3 min par track
                    }
                }

                // 3. Artiste - Titre
                string artist = !string.IsNullOrWhiteSpace(track.DisplayArtist) ? track.DisplayArtist : "Artiste inconnu";
                string title = track.DisplayTitle;

                if (artistFirst)
                {
                    parts.Add($"{artist} - {title}");
                }
                else
                {
                    parts.Add($"{title} - {artist}");
                }

                // 4. BPM & Clé
                if (bpmKey)
                {
                    var extra = new List<string>();
                    if (track.Bpm > 0) extra.Add($"{(int)Math.Round(track.Bpm)} BPM");
                    if (track.CamelotKey != null) extra.Add(track.CamelotKey.ToString());
                    else if (!string.IsNullOrEmpty(track.RawKey)) extra.Add(track.RawKey);

                    if (extra.Count > 0)
                    {
                        parts.Add($"[{string.Join(" • ", extra)}]");
                    }
                }

                sb.AppendLine(string.Join(" ", parts));
            }

            TxtTracklist.Text = sb.ToString();
        }

        private static string FormatTimecode(double totalSeconds)
        {
            var ts = TimeSpan.FromSeconds(Math.Max(0, totalSeconds));
            if (ts.TotalHours >= 1)
            {
                return $"{(int)ts.TotalHours}:{ts.Minutes:D2}:{ts.Seconds:D2}";
            }
            return $"{ts.Minutes:D2}:{ts.Seconds:D2}";
        }

        private static string GenerateM3U8(List<Track> tracks)
        {
            var sb = new StringBuilder();
            sb.AppendLine("#EXTM3U");
            foreach (var t in tracks)
            {
                sb.AppendLine($"#EXTINF:-1,{t.DisplayArtist} - {t.DisplayTitle}");
                if (!string.IsNullOrEmpty(t.FilePath) && File.Exists(t.FilePath))
                {
                    sb.AppendLine(t.FilePath);
                }
                else
                {
                    sb.AppendLine(t.FileName);
                }
            }
            return sb.ToString();
        }

        private async void BtnCopy_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(TxtTracklist.Text)) return;

            try
            {
                Clipboard.SetText(TxtTracklist.Text);
                ToastCopied.Visibility = Visibility.Visible;
                await Task.Delay(1800);
                ToastCopied.Visibility = Visibility.Collapsed;
            }
            catch { }
        }

        private void BtnExportTxt_Click(object sender, RoutedEventArgs e)
        {
            var sfd = new SaveFileDialog
            {
                Filter = "Fichier texte (*.txt)|*.txt|Tous les fichiers (*.*)|*.*",
                FileName = $"Tracklist_Recall_{DateTime.Now:yyyyMMdd_HHmm}.txt"
            };

            if (sfd.ShowDialog() == true)
            {
                try
                {
                    File.WriteAllText(sfd.FileName, TxtTracklist.Text, Encoding.UTF8);
                    MessageBox.Show(this, "Tracklist exportée avec succès !", "Export Réussi", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                catch (Exception ex)
                {
                    MessageBox.Show(this, $"Erreur d'exportation : {ex.Message}", "Erreur", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BtnExportM3u8_Click(object sender, RoutedEventArgs e)
        {
            var tracks = (CmbSource.SelectedIndex == 0) ? _history.PlayedTracks : _toPlay.ToTrackList();
            string m3u8Content = GenerateM3U8(tracks);

            var sfd = new SaveFileDialog
            {
                Filter = "Playlist M3U8 (*.m3u8)|*.m3u8|Tous les fichiers (*.*)|*.*",
                FileName = $"Playlist_Recall_{DateTime.Now:yyyyMMdd_HHmm}.m3u8"
            };

            if (sfd.ShowDialog() == true)
            {
                try
                {
                    File.WriteAllText(sfd.FileName, m3u8Content, Encoding.UTF8);
                    MessageBox.Show(this, "Playlist M3U8 exportée avec succès !", "Export Réussi", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                catch (Exception ex)
                {
                    MessageBox.Show(this, $"Erreur d'exportation : {ex.Message}", "Erreur", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }
    }
}
