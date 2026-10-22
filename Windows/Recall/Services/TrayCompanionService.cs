using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media.Imaging;
using Recall.Models;

namespace Recall.Services
{
    /// <summary>
    /// Service gérant la présence d'un compagnon résident Recall dans la zone de notification Windows (System Tray).
    /// Permet à Recall de rester actif en arrière-plan à l'instar de Pulse DJ.
    /// </summary>
    public class TrayCompanionService
    {
        private static TrayCompanionService? _shared;
        public static TrayCompanionService Shared => _shared ??= new TrayCompanionService();

        private IntPtr _hwnd;
        private HwndSource? _hwndSource;
        private bool _isIconCreated = false;
        private MainWindow? _mainWindow;

        private const int WM_USER = 0x0400;
        private const int WM_TRAYICON = WM_USER + 101;

        private const int NIM_ADD = 0x00000000;
        private const int NIM_MODIFY = 0x00000001;
        private const int NIM_DELETE = 0x00000002;

        private const int NIF_MESSAGE = 0x00000001;
        private const int NIF_ICON = 0x00000002;
        private const int NIF_TIP = 0x00000004;

        private const int WM_LBUTTONUP = 0x0202;
        private const int WM_RBUTTONUP = 0x0205;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct NOTIFYICONDATA
        {
            public int cbSize;
            public IntPtr hWnd;
            public int uID;
            public int uFlags;
            public int uCallbackMessage;
            public IntPtr hIcon;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string szTip;
            public int dwState;
            public int dwStateMask;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
            public string szInfo;
            public int uTimeoutOrVersion;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            public string szInfoTitle;
            public int dwInfoFlags;
            public Guid guidItem;
            public IntPtr hBalloonIcon;
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern bool Shell_NotifyIcon(int dwMessage, ref NOTIFYICONDATA lpData);

        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr LoadImage(IntPtr hinst, string lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

        [DllImport("user32.dll")]
        private static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        private const uint IMAGE_ICON = 1;
        private const uint LR_LOADFROMFILE = 0x0010;
        private const uint LR_DEFAULTSIZE = 0x0040;
        private const uint WM_GETICON = 0x007F;

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT
        {
            public int X;
            public int Y;
        }

        public void Initialize(MainWindow mainWindow)
        {
            _mainWindow = mainWindow;
            var helper = new WindowInteropHelper(mainWindow);
            _hwnd = helper.Handle;

            if (_hwnd != IntPtr.Zero)
            {
                AttachHwndHook();
            }
            else
            {
                mainWindow.SourceInitialized += (s, e) =>
                {
                    _hwnd = new WindowInteropHelper(mainWindow).Handle;
                    AttachHwndHook();
                    if (UserSettings.Shared.AlwaysOnTop) // ou config tray
                    {
                        CreateTrayIcon();
                    }
                };
            }
        }

        private void AttachHwndHook()
        {
            if (_hwndSource == null && _hwnd != IntPtr.Zero)
            {
                _hwndSource = HwndSource.FromHwnd(_hwnd);
                _hwndSource?.AddHook(HwndMessageHook);
                CreateTrayIcon();
            }
        }

        public void CreateTrayIcon()
        {
            if (_isIconCreated || _hwnd == IntPtr.Zero) return;

            try
            {
                IntPtr hIcon = IntPtr.Zero;
                string iconPath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", "AppIcon.ico");
                if (System.IO.File.Exists(iconPath))
                {
                    hIcon = LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE);
                }
                if (hIcon == IntPtr.Zero && _hwnd != IntPtr.Zero)
                {
                    hIcon = SendMessage(_hwnd, WM_GETICON, (IntPtr)0, IntPtr.Zero);
                    if (hIcon == IntPtr.Zero)
                    {
                        hIcon = SendMessage(_hwnd, WM_GETICON, (IntPtr)1, IntPtr.Zero);
                    }
                }

                var nid = new NOTIFYICONDATA
                {
                    cbSize = Marshal.SizeOf<NOTIFYICONDATA>(),
                    hWnd = _hwnd,
                    uID = 1001,
                    uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP,
                    uCallbackMessage = WM_TRAYICON,
                    hIcon = hIcon,
                    szTip = "Recall — Copilote DJ Intelligent"
                };

                _isIconCreated = Shell_NotifyIcon(NIM_ADD, ref nid);
            }
            catch { }
        }

        public void RemoveTrayIcon()
        {
            if (!_isIconCreated || _hwnd == IntPtr.Zero) return;

            try
            {
                var nid = new NOTIFYICONDATA
                {
                    cbSize = Marshal.SizeOf<NOTIFYICONDATA>(),
                    hWnd = _hwnd,
                    uID = 1001
                };
                Shell_NotifyIcon(NIM_DELETE, ref nid);
                _isIconCreated = false;
            }
            catch { }
        }

        private IntPtr HwndMessageHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WM_TRAYICON)
            {
                int mouseEvent = (int)lParam;
                if (mouseEvent == WM_LBUTTONUP)
                {
                    ToggleRecallVisibility();
                    handled = true;
                }
                else if (mouseEvent == WM_RBUTTONUP)
                {
                    ShowTrayContextMenu();
                    handled = true;
                }
            }
            return IntPtr.Zero;
        }

        private void ToggleRecallVisibility()
        {
            if (_mainWindow == null) return;

            if (_mainWindow.IsVisible)
            {
                _mainWindow.Hide();
            }
            else
            {
                _mainWindow.Show();
                _mainWindow.WindowState = WindowState.Normal;
                _mainWindow.Activate();
            }
        }

        private void ShowTrayContextMenu()
        {
            if (_mainWindow == null) return;

            SetForegroundWindow(_hwnd);

            var monitor = SeratoMonitorService.Shared;
            var session = SessionHistoryService.Shared;
            var settings = UserSettings.Shared;

            var menu = new ContextMenu
            {
                Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(22, 26, 34)),
                BorderBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromArgb(90, 255, 255, 255)),
                BorderThickness = new Thickness(1),
                Foreground = System.Windows.Media.Brushes.White
            };

            // 1. En-tête : Titre & Version
            var headerItem = new MenuItem
            {
                Header = "Recall • Copilote DJ (v1.0.13)",
                IsEnabled = false,
                FontWeight = FontWeights.Bold,
                Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(20, 200, 176))
            };
            menu.Items.Add(headerItem);

            // 2. Statut en direct
            string statusStr = "🎧 En attente du logiciel DJ";
            if (monitor.CurrentTrack != null)
            {
                statusStr = $"▶️ {monitor.CurrentTrack.DisplayArtist} — {monitor.CurrentTrack.DisplayTitle}";
            }
            else if (monitor.IsSeratoConnected)
            {
                statusStr = $"🟢 Serato DJ Pro connecté ({session.PlayedCount} joués)";
            }
            else if (monitor.IsRekordboxConnected)
            {
                statusStr = $"🟢 Rekordbox connecté ({session.PlayedCount} joués)";
            }

            var statusItem = new MenuItem
            {
                Header = statusStr,
                IsEnabled = false,
                Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(156, 163, 175))
            };
            menu.Items.Add(statusItem);

            menu.Items.Add(new Separator());

            // 3. Afficher / Masquer Recall
            var toggleItem = new MenuItem
            {
                Header = _mainWindow.IsVisible ? "Masquer Recall" : "Afficher Recall"
            };
            toggleItem.Click += (s, e) => ToggleRecallVisibility();
            menu.Items.Add(toggleItem);

            var recenterItem = new MenuItem
            {
                Header = "Recentrer en bas à droite"
            };
            recenterItem.Click += (s, e) =>
            {
                _mainWindow.PositionAtBottomRight();
                _mainWindow.Show();
                _mainWindow.Activate();
            };
            menu.Items.Add(recenterItem);

            menu.Items.Add(new Separator());

            // 4. Outils DJ
            var recapItem = new MenuItem
            {
                Header = "Statistiques du Mix (Set Recap)..."
            };
            recapItem.Click += (s, e) => _mainWindow.OpenSetRecap();
            menu.Items.Add(recapItem);

            var tracklistItem = new MenuItem
            {
                Header = "Générateur de Tracklist..."
            };
            tracklistItem.Click += (s, e) => _mainWindow.OpenTracklistGenerator();
            menu.Items.Add(tracklistItem);

            var resyncItem = new MenuItem
            {
                Header = "Resynchroniser avec le logiciel DJ"
            };
            resyncItem.Click += (s, e) => monitor.PollSoftware();
            menu.Items.Add(resyncItem);

            menu.Items.Add(new Separator());

            // 5. Paramètres & Démarrage
            var settingsItem = new MenuItem
            {
                Header = "Paramètres..."
            };
            settingsItem.Click += (s, e) => _mainWindow.OpenSettings();
            menu.Items.Add(settingsItem);

            var startupItem = new MenuItem
            {
                Header = "Lancer au démarrage de Windows",
                IsCheckable = true,
                IsChecked = LaunchAtStartupService.IsLaunchAtStartupEnabled()
            };
            startupItem.Click += (s, e) =>
            {
                bool newState = !LaunchAtStartupService.IsLaunchAtStartupEnabled();
                LaunchAtStartupService.SetLaunchAtStartup(newState);
            };
            menu.Items.Add(startupItem);

            menu.Items.Add(new Separator());

            // 6. Quitter
            var quitItem = new MenuItem
            {
                Header = "Quitter Recall",
                Foreground = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 82, 82))
            };
            quitItem.Click += (s, e) => Application.Current.Shutdown();
            menu.Items.Add(quitItem);

            menu.IsOpen = true;
        }
    }
}
