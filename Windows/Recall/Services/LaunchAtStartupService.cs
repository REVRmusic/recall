using System;
using System.Diagnostics;
using Microsoft.Win32;

namespace Recall.Services
{
    /// <summary>
    /// Service gérant le lancement automatique de Recall au démarrage de Windows (via le Registre Windows HKCU).
    /// </summary>
    public static class LaunchAtStartupService
    {
        private const string RunRegistryKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AppName = "Recall";

        public static bool IsLaunchAtStartupEnabled()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunRegistryKey, false);
                if (key == null) return false;
                var val = key.GetValue(AppName) as string;
                return !string.IsNullOrEmpty(val);
            }
            catch
            {
                return false;
            }
        }

        public static bool SetLaunchAtStartup(bool enabled)
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunRegistryKey, true);
                if (key == null) return false;

                if (enabled)
                {
                    string? exePath = Environment.ProcessPath;
                    if (string.IsNullOrEmpty(exePath))
                    {
                        exePath = Process.GetCurrentProcess().MainModule?.FileName;
                    }

                    if (!string.IsNullOrEmpty(exePath))
                    {
                        key.SetValue(AppName, $"\"{exePath}\"");
                        return true;
                    }
                }
                else
                {
                    if (key.GetValue(AppName) != null)
                    {
                        key.DeleteValue(AppName, false);
                    }
                    return true;
                }
            }
            catch
            {
                return false;
            }

            return false;
        }
    }
}
