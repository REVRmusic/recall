using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using Recall.Models;

namespace Recall
{
    public partial class SettingsWindow : Window
    {
        private readonly UserSettings _settings = UserSettings.Shared;

        public SettingsWindow()
        {
            InitializeComponent();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            LoadSettings();
        }

        private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ButtonState == MouseButtonState.Pressed)
            {
                DragMove();
            }
        }

        private void LoadSettings()
        {
            TxtDbPath.Text = _settings.EffectiveDatabasePath;
            TxtRbXmlPath.Text = _settings.EffectiveRekordboxXmlPath;
            ChkAlwaysOnTop.IsChecked = _settings.AlwaysOnTop;
            ChkHidePlayed.IsChecked = _settings.HidePlayedTracks;

            // DJ Software Mode
            foreach (ComboBoxItem item in CmbDjSoftware.Items)
            {
                if (item.Tag?.ToString() == _settings.DjSoftwareMode)
                {
                    CmbDjSoftware.SelectedItem = item;
                    break;
                }
            }

            // Lookback
            foreach (ComboBoxItem item in CmbLookback.Items)
            {
                if (int.TryParse(item.Tag?.ToString(), out int val) && val == _settings.HistoryDaysLookback)
                {
                    CmbLookback.SelectedItem = item;
                    break;
                }
            }

            // BPM Tol
            foreach (ComboBoxItem item in CmbBpmTol.Items)
            {
                if (double.TryParse(item.Tag?.ToString(), out double val) && Math.Abs(val - _settings.BpmTolerancePercent) < 0.1)
                {
                    CmbBpmTol.SelectedItem = item;
                    break;
                }
            }

            // Max suggestions
            foreach (ComboBoxItem item in CmbMaxSug.Items)
            {
                if (int.TryParse(item.Tag?.ToString(), out int val) && val == _settings.MaxSuggestions)
                {
                    CmbMaxSug.SelectedItem = item;
                    break;
                }
            }

            // Key display mode
            foreach (ComboBoxItem item in CmbKeyDisplayMode.Items)
            {
                if (int.TryParse(item.Tag?.ToString(), out int kMode) && kMode == _settings.KeyDisplayMode)
                {
                    CmbKeyDisplayMode.SelectedItem = item;
                    break;
                }
            }
        }

        private void BtnBrowseRbXml_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new OpenFileDialog
            {
                Title = "Sélectionnez votre collection Rekordbox XML",
                Filter = "Collection XML (*.xml)|*.xml|Tous les fichiers (*.*)|*.*",
                InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments)
            };

            if (dialog.ShowDialog() == true)
            {
                TxtRbXmlPath.Text = dialog.FileName;
            }
        }

        private void BtnBrowseDb_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new OpenFileDialog
            {
                Title = "Sélectionnez votre fichier master.sqlite Serato",
                Filter = "Base Serato (master.sqlite)|master.sqlite|Tous les fichiers (*.*)|*.*",
                InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
            };

            if (dialog.ShowDialog() == true)
            {
                TxtDbPath.Text = dialog.FileName;
            }
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            if (CmbDjSoftware.SelectedItem is ComboBoxItem itemMode && itemMode.Tag != null)
            {
                _settings.DjSoftwareMode = itemMode.Tag.ToString()!;
            }

            _settings.RekordboxXmlCustomPath = TxtRbXmlPath.Text.Trim();

            string chosenPath = TxtDbPath.Text.Trim();
            if (chosenPath.Equals(_settings.DefaultDatabasePath, StringComparison.OrdinalIgnoreCase))
            {
                _settings.SeratoDatabaseCustomPath = "";
            }
            else
            {
                _settings.SeratoDatabaseCustomPath = chosenPath;
            }

            _settings.AlwaysOnTop = ChkAlwaysOnTop.IsChecked == true;
            _settings.HidePlayedTracks = ChkHidePlayed.IsChecked == true;

            if (CmbLookback.SelectedItem is ComboBoxItem itemLb && int.TryParse(itemLb.Tag?.ToString(), out int lb))
            {
                _settings.HistoryDaysLookback = lb;
            }

            if (CmbBpmTol.SelectedItem is ComboBoxItem itemBpm && double.TryParse(itemBpm.Tag?.ToString(), out double tol))
            {
                _settings.BpmTolerancePercent = tol;
            }

            if (CmbMaxSug.SelectedItem is ComboBoxItem itemMax && int.TryParse(itemMax.Tag?.ToString(), out int maxS))
            {
                _settings.MaxSuggestions = maxS;
            }

            if (CmbKeyDisplayMode.SelectedItem is ComboBoxItem itemKey && int.TryParse(itemKey.Tag?.ToString(), out int kdm))
            {
                _settings.KeyDisplayMode = kdm;
            }

            _settings.Save();
            DialogResult = true;
            Close();
        }

        private void BtnReset_Click(object sender, RoutedEventArgs e)
        {
            _settings.DjSoftwareMode = "auto";
            _settings.RekordboxXmlCustomPath = "";
            _settings.SeratoDatabaseCustomPath = "";
            _settings.HistoryDaysLookback = 360;
            _settings.BpmTolerancePercent = 8.0;
            _settings.MaxSuggestions = 30;
            _settings.AlwaysOnTop = true;
            _settings.HidePlayedTracks = false;
            _settings.KeyDisplayMode = 0;
            LoadSettings();
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }

        private void BtnFeedback_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "https://mixify.fr/?feedback=1&source=app_windows",
                    UseShellExecute = true
                });
            }
            catch { }
        }
    }
}
