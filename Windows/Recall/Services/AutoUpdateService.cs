using System;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using System.Windows;

namespace Recall.Services
{
    public class GitHubAsset
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("browser_download_url")]
        public string BrowserDownloadUrl { get; set; } = string.Empty;

        [JsonPropertyName("size")]
        public long? Size { get; set; }
    }

    public class GitHubRelease
    {
        [JsonPropertyName("tag_name")]
        public string TagName { get; set; } = string.Empty;

        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("body")]
        public string? Body { get; set; }

        [JsonPropertyName("html_url")]
        public string HtmlUrl { get; set; } = string.Empty;

        [JsonPropertyName("assets")]
        public GitHubAsset[] Assets { get; set; } = Array.Empty<GitHubAsset>();
    }

    public class AutoUpdateService
    {
        private static AutoUpdateService? _shared;
        public static AutoUpdateService Shared => _shared ??= new AutoUpdateService();

        private const string CurrentAppVersion = "1.0.0";
        private const string RepoApiUrl = "https://api.github.com/repos/REVRmusic/recall/releases/latest";

        private bool _hasCheckedOnStartup = false;

        public bool IsUpdateAvailable { get; private set; } = false;
        public string? AvailableVersion { get; private set; }
        public string? DownloadUrl { get; private set; }

        /// <summary>
        /// Recherche de mise à jour au démarrage de Recall :
        /// - Déclenchée strictement une seule fois lors du démarrage
        /// - Vérifie en amont la présence d'une connexion internet active (sans appel réseau si hors-ligne)
        /// - Exécutée en tâche de fond asynchrone après 3s pour ne jamais ralentir le lancement
        /// - 100% sécurisée avec timeout strict de 5s et capture de toutes les exceptions pour garantir zéro plantage
        /// </summary>
        public void CheckForUpdatesOnStartup()
        {
            if (_hasCheckedOnStartup) return;
            _hasCheckedOnStartup = true;

            Task.Run(async () =>
            {
                try
                {
                    // Délai de courtoisie de 3s : priorité au chargement de l'interface et des decks DJ
                    await Task.Delay(3000);

                    // Vérification de la connectivité réseau
                    if (!NetworkInterface.GetIsNetworkAvailable())
                    {
                        // Hors-ligne (ex: régie DJ, club, sans réseau) -> sortie immédiate et silencieuse
                        return;
                    }

                    using var client = new HttpClient();
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("User-Agent", $"Recall-Windows/{CurrentAppVersion}");
                    client.DefaultRequestHeaders.Add("Accept", "application/vnd.github.v3+json");

                    var response = await client.GetAsync(RepoApiUrl);
                    if (!response.IsSuccessStatusCode) return;

                    var json = await response.Content.ReadAsStringAsync();
                    var release = JsonSerializer.Deserialize<GitHubRelease>(json);
                    if (release == null || string.IsNullOrWhiteSpace(release.TagName)) return;

                    if (IsVersion(release.TagName, greaterThan: CurrentAppVersion))
                    {
                        // Trouver l'asset Windows (.zip) en priorité
                        var winAsset = release.Assets.FirstOrDefault(a =>
                            a.Name.IndexOf("win", StringComparison.OrdinalIgnoreCase) >= 0 &&
                            a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase));

                        var finalUrl = winAsset?.BrowserDownloadUrl ?? release.HtmlUrl;

                        Application.Current?.Dispatcher.Invoke(() =>
                        {
                            IsUpdateAvailable = true;
                            AvailableVersion = release.TagName;
                            DownloadUrl = finalUrl;
                        });
                    }
                }
                catch (Exception)
                {
                    // Erreur silencieusement ignorée : l'application DJ ne doit JAMAIS planter au démarrage
                }
            });
        }

        public void OpenDownloadInBrowser()
        {
            try
            {
                var targetUrl = !string.IsNullOrWhiteSpace(DownloadUrl)
                    ? DownloadUrl
                    : "https://github.com/REVRmusic/recall/releases/latest";

                Process.Start(new ProcessStartInfo(targetUrl)
                {
                    UseShellExecute = true
                });
            }
            catch (Exception)
            {
                // Ignore
            }
        }

        public static int[] ParseVersionComponents(string version)
        {
            var clean = (version ?? string.Empty).Trim();
            if (clean.StartsWith("v", StringComparison.OrdinalIgnoreCase))
            {
                clean = clean.Substring(1);
            }
            var dashIndex = clean.IndexOf('-');
            if (dashIndex >= 0)
            {
                clean = clean.Substring(0, dashIndex);
            }

            return clean.Split('.', StringSplitOptions.RemoveEmptyEntries)
                        .Select(p => int.TryParse(p, out var v) ? v : 0)
                        .ToArray();
        }

        public static bool IsVersion(string remote, bool greaterThan, string current)
        {
            var remoteParts = ParseVersionComponents(remote);
            var currentParts = ParseVersionComponents(current);

            var maxLen = Math.Max(remoteParts.Length, currentParts.Length);
            for (int i = 0; i < maxLen; i++)
            {
                var r = i < remoteParts.Length ? remoteParts[i] : 0;
                var c = i < currentParts.Length ? currentParts[i] : 0;
                if (r > c) return true;
                if (r < c) return false;
            }
            return false;
        }
    }
}
