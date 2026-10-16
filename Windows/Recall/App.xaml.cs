using System.Windows;
using Recall.Services;

namespace Recall
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Recherche automatique de mise à jour au démarrage (uniquement si connecté à Internet)
            AutoUpdateService.Shared.CheckForUpdatesOnStartup();
        }
    }
}
