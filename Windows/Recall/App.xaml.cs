using System.Windows;
using Recall.Models;
using Recall.Services;

namespace Recall
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Application du thème DJ actif
            DJThemeManager.ApplyTheme(UserSettings.Shared.DjTheme);

            // Recherche automatique de mise à jour au démarrage (uniquement si connecté à Internet)
            AutoUpdateService.Shared.CheckForUpdatesOnStartup();
        }
    }
}
