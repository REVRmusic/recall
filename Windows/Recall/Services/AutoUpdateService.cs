using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
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

        public const string CurrentAppVersion = "1.0.11";
        public string Version => CurrentAppVersion;

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

                    if (IsVersionGreaterThan(release.TagName, CurrentAppVersion))
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

        /// <summary>
        /// Recherche manuelle déclenchée depuis les paramètres de l'application
        /// </summary>
        public async Task<(bool success, bool hasUpdate, string version, string url, string message)> CheckForUpdatesManualAsync()
        {
            try
            {
                if (!NetworkInterface.GetIsNetworkAvailable())
                {
                    return (false, false, "", "", "Aucune connexion Internet détectée.");
                }

                using var client = new HttpClient();
                client.Timeout = TimeSpan.FromSeconds(6);
                client.DefaultRequestHeaders.Add("User-Agent", $"Recall-Windows/{CurrentAppVersion}");
                client.DefaultRequestHeaders.Add("Accept", "application/vnd.github.v3+json");

                var response = await client.GetAsync(RepoApiUrl);
                if (!response.IsSuccessStatusCode)
                {
                    return (false, false, "", "", $"Serveur inaccessible (Code {(int)response.StatusCode}).");
                }

                var json = await response.Content.ReadAsStringAsync();
                var release = JsonSerializer.Deserialize<GitHubRelease>(json);
                if (release == null || string.IsNullOrWhiteSpace(release.TagName))
                {
                    return (false, false, "", "", "Impossible d'analyser la version distante.");
                }

                if (IsVersionGreaterThan(release.TagName, CurrentAppVersion))
                {
                    var winAsset = release.Assets.FirstOrDefault(a =>
                        a.Name.IndexOf("win", StringComparison.OrdinalIgnoreCase) >= 0 &&
                        a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase));

                    var finalUrl = winAsset?.BrowserDownloadUrl ?? release.HtmlUrl;

                    IsUpdateAvailable = true;
                    AvailableVersion = release.TagName;
                    DownloadUrl = finalUrl;

                    return (true, true, release.TagName, finalUrl, $"Nouvelle version {release.TagName} disponible !");
                }
                else
                {
                    IsUpdateAvailable = false;
                    return (true, false, release.TagName, "", $"Recall est à jour (v{CurrentAppVersion}).");
                }
            }
            catch (Exception ex)
            {
                return (false, false, "", "", $"Erreur de vérification : {ex.Message}");
            }
        }

        /// <summary>
        /// Télécharge automatiquement Recall-Windows.zip, extrait le nouvel exécutable,
        /// remplace Recall.exe en place et relance l'application.
        /// </summary>
        public async Task<(bool success, string message)> InstallUpdateAndRestartAsync(IProgress<string>? statusProgress = null)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(DownloadUrl) || !DownloadUrl.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                {
                    OpenDownloadInBrowser();
                    return (true, "Ouverture du téléchargement dans le navigateur...");
                }

                statusProgress?.Report($"Téléchargement de Recall {AvailableVersion} en cours...");

                var workDir = Path.Combine(Path.GetTempPath(), "RecallUpdate-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(workDir);
                var zipPath = Path.Combine(workDir, "Recall-Windows.zip");
                var extractDir = Path.Combine(workDir, "extracted");

                using (var client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromMinutes(3);
                    client.DefaultRequestHeaders.Add("User-Agent", $"Recall-Windows/{CurrentAppVersion}");
                    using var response = await client.GetAsync(DownloadUrl, HttpCompletionOption.ResponseHeadersRead);
                    response.EnsureSuccessStatusCode();
                    await using var fs = new FileStream(zipPath, FileMode.Create, FileAccess.Write, FileShare.None);
                    await response.Content.CopyToAsync(fs);
                }

                statusProgress?.Report("Extraction et vérification de la mise à jour...");
                ZipFile.ExtractToDirectory(zipPath, extractDir, true);

                var newExePath = Directory.GetFiles(extractDir, "Recall.exe", SearchOption.AllDirectories).FirstOrDefault();
                if (string.IsNullOrEmpty(newExePath) || !File.Exists(newExePath))
                {
                    return (false, "Fichier Recall.exe introuvable dans l'archive téléchargée.");
                }

                var currentExePath = Process.GetCurrentProcess().MainModule?.FileName;
                if (string.IsNullOrEmpty(currentExePath))
                {
                    OpenDownloadInBrowser();
                    return (false, "Impossible de déterminer l'emplacement actuel de Recall.exe.");
                }

                var pid = Environment.ProcessId;
                var batPath = Path.Combine(workDir, "install_update.bat");
                var batContent = $@"@echo off
timeout /t 1 /nobreak >nul
:waitloop
tasklist /FI ""PID eq {pid}"" 2>NUL | find /I ""{pid}"" >NUL
if ""%ERRORLEVEL%""==""0"" (
    timeout /t 1 /nobreak >nul
    goto waitloop
)
copy /Y ""{newExePath}"" ""{currentExePath}"" >nul
start """" ""{currentExePath}""
rmdir /S /Q ""{workDir}"" 2>nul
";
                await File.WriteAllTextAsync(batPath, batContent);

                statusProgress?.Report("Redémarrage de Recall...");

                Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/C \"{batPath}\"",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                });

                Application.Current?.Dispatcher.Invoke(() =>
                {
                    Application.Current.Shutdown();
                });

                return (true, "Redémarrage en cours...");
            }
            catch (Exception ex)
            {
                OpenDownloadInBrowser();
                return (false, $"Installation automatique impossible ({ex.Message}). Téléchargement ouvert dans le navigateur.");
            }
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

        public static bool IsVersionGreaterThan(string remote, string current)
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
