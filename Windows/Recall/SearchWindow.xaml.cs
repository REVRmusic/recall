using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Recall.Models;
using Recall.Services;

namespace Recall
{
    public partial class SearchWindow : Window
    {
        private readonly SeratoDatabaseService _dbService = new();
        private readonly SeratoMonitorService _monitor = SeratoMonitorService.Shared;

        public SearchWindow()
        {
            InitializeComponent();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            TxtHeaderTitle.Text = _monitor.ActiveDJSoftware == "rekordbox" ? "Rechercher dans Rekordbox" : "Rechercher dans la bibliothèque Serato";
            TxtSearch.Focus();
        }

        private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ButtonState == MouseButtonState.Pressed)
            {
                DragMove();
            }
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }

        private void BtnClear_Click(object sender, RoutedEventArgs e)
        {
            TxtSearch.Text = "";
            TxtSearch.Focus();
        }

        private async void TxtSearch_TextChanged(object sender, TextChangedEventArgs e)
        {
            string q = TxtSearch.Text.Trim();
            BtnClear.Visibility = string.IsNullOrEmpty(q) ? Visibility.Collapsed : Visibility.Visible;

            if (q.Length < 2)
            {
                ListResults.ItemsSource = null;
                TxtEmptyState.Text = "Tapez au moins 2 lettres pour lancer la recherche...";
                TxtEmptyState.Visibility = Visibility.Visible;
                TxtResultsCount.Text = "";
                return;
            }

            TxtEmptyState.Text = "Recherche en cours...";
            TxtEmptyState.Visibility = Visibility.Visible;

            bool isRekordbox = _monitor.ActiveDJSoftware == "rekordbox";

            var results = await Task.Run(() =>
            {
                if (isRekordbox)
                {
                    return RekordboxService.Shared.SearchTracks(q, 40);
                }
                else
                {
                    return _dbService.SearchTracks(q, 40);
                }
            });

            if (results.Count == 0)
            {
                ListResults.ItemsSource = null;
                TxtEmptyState.Text = "Aucun résultat trouvé pour « " + q + " »";
                TxtEmptyState.Visibility = Visibility.Visible;
                TxtResultsCount.Text = "0 résultat";
            }
            else
            {
                TxtEmptyState.Visibility = Visibility.Collapsed;
                ListResults.ItemsSource = results;
                TxtResultsCount.Text = $"{results.Count} résultat{(results.Count > 1 ? "s" : "")}";
            }
        }

        private void ListResults_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ListResults.SelectedItem is Track selected)
            {
                _monitor.SetManualReferenceTrack(selected);
                Close();
            }
        }
    }
}
