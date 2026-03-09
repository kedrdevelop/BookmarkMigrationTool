using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;

namespace BookmarkMigrator
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        // Constants
        private const string LogFileName = "migration_log.txt";
        private const string BackupRootFolderName = "BookmarksBackup";
        private const string ChromeFolderName = "Chrome";
        private const string EdgeFolderName = "Edge";
        private const string BookmarksFileName = "Bookmarks";
        private const string DefaultProfileName = "Default";
        private const string ProfileFolderPrefix = "Profile";
        private const string ChromeImportPrefix = "Chrome_";
        private const int InitialIdCounter = 100000;
        private const int BrowserCloseWaitTimeMs = 1500;

        // State variables for migration logic
        private string _backupFolderPath = string.Empty;
        private string _logFilePath = string.Empty;

        public MainWindow()
        {
            InitializeComponent();
            
            // Start analysis immediately after loading
            Loaded += async (s, e) => await CheckBrowserProcessesAsync();
        }

        /// <summary>
        /// Step 1: Checks if Chrome or Edge processes are currently running.
        /// Determines the initial state of the UI.
        /// </summary>
        private async Task CheckBrowserProcessesAsync()
        {
            WriteLogToFile("INFO", "Checking browser processes...");

            await Task.Run(() =>
            {
                var chromeProcesses = Process.GetProcessesByName("chrome");
                var edgeProcesses = Process.GetProcessesByName("msedge");
                bool areBrowsersRunning = chromeProcesses.Length > 0 || edgeProcesses.Length > 0;

                Dispatcher.Invoke(() =>
                {
                    if (areBrowsersRunning)
                    {
                        // State: Browsers Running
                        DeMessageText.Text = "Browser laufen derzeit. Bitte speichern Sie Ihre Arbeit, bevor Sie schließen.";
                        EnMessageText.Text = "Browsers are currently running. Please save your work before closing.";
                        
                        SetMessageState("Warning");
                        UpdateStepper(1); // Check Active
                        
                        BtnCloseBrowsers.Visibility = Visibility.Visible;
                        BtnStartMigration.Visibility = Visibility.Collapsed;
                        BtnCloseApp.Visibility = Visibility.Collapsed;
                    }
                    else
                    {
                        // State: Ready for Migration
                        DeMessageText.Text = "Bereit zum Migrieren der Lesezeichen von Chrome zu Edge.";
                        EnMessageText.Text = "Ready to migrate bookmarks from Chrome to Edge.";
                        
                        SetMessageState("Normal");
                        UpdateStepper(2); // Check Done, Migrate Ready (Active)

                        BtnCloseBrowsers.Visibility = Visibility.Collapsed;
                        BtnStartMigration.Visibility = Visibility.Visible;
                        BtnCloseApp.Visibility = Visibility.Collapsed;
                    }
                });
            });
        }

        /// <summary>
        /// Writes a log message to a text file instead of the UI.
        /// Uses the dynamically created log file if available, otherwise falls back to local file.
        /// </summary>
        private void WriteLogToFile(string level, string message)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                string logEntry = $"[{timestamp}] [{level}] {message}{Environment.NewLine}";
                
                string targetFile = !string.IsNullOrEmpty(_logFilePath) ? _logFilePath : LogFileName;
                File.AppendAllText(targetFile, logEntry);
            }
            catch
            {
                // Ignore logging errors to prevent app crash
            }
        }

        private async void BtnStartMigration_Click(object sender, RoutedEventArgs e)
        {
            // UI: Lock interface
            BtnStartMigration.Visibility = Visibility.Collapsed;
            BtnCloseBrowsers.Visibility = Visibility.Collapsed;
            
            DeMessageText.Text = "Lesezeichen werden migriert...";
            EnMessageText.Text = "Migrating bookmarks...";
            SetMessageState("Normal");
            UpdateStepper(2); // Migrate Active

            try
            {
                await Task.Run(() =>
                {
                    // Step 1: Initialize Backup
                    WriteLogToFile("INFO", "Starting migration process.");
                    InitializeBackupFolder();

                    // Step 2: Locate Profiles
                    var chromeProfiles = GetChromeProfiles();
                    var edgeProfile = GetEdgeTargetProfile();

                    if (chromeProfiles.Count == 0) throw new Exception("No Chrome profiles found.");
                    if (string.IsNullOrEmpty(edgeProfile)) throw new Exception("No Edge profile found.");

                    // Step 3: Backup
                    BackupBookmarks(chromeProfiles, edgeProfile!);

                    // Step 4 & 5: Merge Logic
                    MergeBookmarks(chromeProfiles, edgeProfile!);

                    // Step 6: Validation
                    TestMigration(edgeProfile!);
                });

                // State: Success
                WriteLogToFile("INFO", "Migration completed successfully.");
                UpdateStepper(3); // Done Active

                DeMessageText.Text = "Migration erfolgreich!";
                EnMessageText.Text = "Migration successful!";
                SetMessageState("Success");

                DeActionText.Text = "Hinweis: Der importierte Ordner erscheint möglicherweise am Ende Ihrer Lesezeichenleiste. Bitte öffnen Sie Edge und ziehen Sie ihn manuell an den Anfang.";
                EnActionText.Text = "Note: The imported folder might appear at the end of your bookmarks bar. Please open Edge and drag it to the beginning manually.";
                ActionRequiredContainer.Visibility = Visibility.Visible;
                

                BtnCloseApp.Visibility = Visibility.Visible;
            }
            catch (Exception ex)
            {
                // Handle Rollback and UI Error State
                await Task.Run(() => InvokeRollback(ex));

                DeMessageText.Text = $"Ein Fehler ist aufgetreten. Änderungen wurden rückgängig gemacht.\nFehler: {ex.Message}\nKontaktieren Sie den Entwickler: viacheslav.kedrov@servier.com";
                EnMessageText.Text = $"An error occurred. Changes have been rolled back.\nError: {ex.Message}\nContact developer: viacheslav.kedrov@servier.com";

                SetMessageState("Error");

                BtnCloseApp.Visibility = Visibility.Visible;
            }
        }

        /// <summary>
        /// Updates the visual state of the message container and text colors.
        /// </summary>
        private void SetMessageState(string state)
        {
            if (state == "Warning")
            {
                // Amber Background for Warning
                MessageContainer.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#332D16"));
                var warningText = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#E6C762"));
                DeMessageText.Foreground = warningText;
                EnMessageText.Foreground = warningText;
            }
            else if (state == "Error")
            {
                MessageContainer.Background = Brushes.Transparent;
                var errorBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#F2B8B5"));
                DeMessageText.Foreground = errorBrush;
                EnMessageText.Foreground = errorBrush;
            }
            else if (state == "Success")
            {
                MessageContainer.Background = Brushes.Transparent;
                var successBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#B7F397")); // Light Green
                DeMessageText.Foreground = successBrush;
                EnMessageText.Foreground = successBrush;
            }
            else // Normal
            {
                MessageContainer.Background = Brushes.Transparent;
                DeMessageText.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#E6E1E5"));
                EnMessageText.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#CAC4D0"));
            }
        }

        /// <summary>
        /// Updates the 3-step progress indicator.
        /// </summary>
        private void UpdateStepper(int step)
        {
            // Colors
            var activeBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#A8C7FA"));
            var activeTextBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#062E6F"));
            
            var doneBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#66BB6A")); // Muted Green
            var futureBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#49454F"));
            
            // Reset all to future first
            Step1Container.Background = Brushes.Transparent; Step1Container.BorderBrush = futureBrush; Step1Text.Foreground = futureBrush;
            Step2Container.Background = Brushes.Transparent; Step2Container.BorderBrush = futureBrush; Step2Text.Foreground = futureBrush;
            Step3Container.Background = Brushes.Transparent; Step3Container.BorderBrush = futureBrush; Step3Text.Foreground = futureBrush;

            if (step == 1) // Check Active
            {
                Step1Container.Background = activeBrush; Step1Container.BorderBrush = activeBrush; Step1Text.Foreground = activeTextBrush;
            }
            else if (step == 2) // Migrate Active (Check Done)
            {
                Step1Container.BorderBrush = doneBrush; Step1Text.Foreground = doneBrush;
                Step2Container.Background = activeBrush; Step2Container.BorderBrush = activeBrush; Step2Text.Foreground = activeTextBrush;
            }
            else if (step == 3) // Done Active (Check & Migrate Done)
            {
                Step1Container.BorderBrush = doneBrush; Step1Text.Foreground = doneBrush;
                Step2Container.BorderBrush = doneBrush; Step2Text.Foreground = doneBrush;
                Step3Container.Background = activeBrush; Step3Container.BorderBrush = activeBrush; Step3Text.Foreground = activeTextBrush;
            }
        }

        #region Core Migration Logic

        /// <summary>
        /// Step 1: Creates backup directory structure on Desktop and initializes logging.
        /// </summary>
        private void InitializeBackupFolder()
        {
            string desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
            string timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
            _backupFolderPath = Path.Combine(desktop, BackupRootFolderName, $"{timestamp}_Migration");

            Directory.CreateDirectory(_backupFolderPath);
            Directory.CreateDirectory(Path.Combine(_backupFolderPath, ChromeFolderName));
            Directory.CreateDirectory(Path.Combine(_backupFolderPath, EdgeFolderName));

            _logFilePath = Path.Combine(_backupFolderPath, LogFileName);
            WriteLogToFile("INFO", $"Backup folder created at: {_backupFolderPath}");
        }

        /// <summary>
        /// Step 2a: Scans for Chrome profiles containing Bookmarks.
        /// </summary>
        private List<string> GetChromeProfiles()
        {
            var profiles = new List<string>();
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string chromeUserData = Path.Combine(localAppData, "Google", "Chrome", "User Data");

            if (!Directory.Exists(chromeUserData)) return profiles;

            // Check Default and Profile X folders
            var dirs = Directory.GetDirectories(chromeUserData);
            foreach (var dir in dirs)
            {
                string dirName = new DirectoryInfo(dir).Name;
                if (dirName.Equals(DefaultProfileName, StringComparison.OrdinalIgnoreCase) || dirName.StartsWith(ProfileFolderPrefix, StringComparison.OrdinalIgnoreCase))
                {
                    if (File.Exists(Path.Combine(dir, BookmarksFileName)))
                    {
                        profiles.Add(dir);
                        WriteLogToFile("INFO", $"Found Chrome profile: {dirName}");
                    }
                }
            }
            return profiles;
        }

        /// <summary>
        /// Step 2b: Finds the oldest Edge profile (usually the main one).
        /// </summary>
        private string? GetEdgeTargetProfile()
        {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string edgeUserData = Path.Combine(localAppData, "Microsoft", "Edge", "User Data");

            if (!Directory.Exists(edgeUserData)) return null;

            var dirs = Directory.GetDirectories(edgeUserData)
                .Where(d => 
                {
                    string name = new DirectoryInfo(d).Name;
                    return name.Equals(DefaultProfileName, StringComparison.OrdinalIgnoreCase) || name.StartsWith(ProfileFolderPrefix, StringComparison.OrdinalIgnoreCase);
                })
                .OrderBy(d => Directory.GetCreationTime(d)) // Oldest first
                .ToList();

            if (dirs.Any())
            {
                WriteLogToFile("INFO", $"Target Edge profile selected: {new DirectoryInfo(dirs.First()).Name}");
                return dirs.First();
            }
            return null;
        }

        /// <summary>
        /// Step 3: Copies original bookmark files to the backup directory.
        /// </summary>
        private void BackupBookmarks(List<string> chromeProfilePaths, string edgeProfilePath)
        {
            // Backup Chrome
            foreach (var profilePath in chromeProfilePaths)
            {
                string folderName = new DirectoryInfo(profilePath).Name;
                string source = Path.Combine(profilePath, BookmarksFileName);
                string dest = Path.Combine(_backupFolderPath, ChromeFolderName, $"{folderName}_{BookmarksFileName}");
                File.Copy(source, dest, true);
            }

            // Backup Edge
            string edgeSource = Path.Combine(edgeProfilePath, BookmarksFileName);
            if (File.Exists(edgeSource))
            {
                string edgeDest = Path.Combine(_backupFolderPath, EdgeFolderName, BookmarksFileName);
                File.Copy(edgeSource, edgeDest, true);
                WriteLogToFile("INFO", "Edge bookmarks backed up.");
            }
            else
            {
                WriteLogToFile("WARN", "No existing Edge bookmarks file found. A new one will be created.");
            }
        }

        /// <summary>
        /// Step 4: Recursively resets IDs and GUIDs for bookmark nodes.
        /// </summary>
        private void ResetBookmarkMetadata(JsonNode? node, ref int idCounter)
        {
            if (node == null) return;

            // Update ID and GUID
            node["id"] = idCounter.ToString();
            idCounter++;
            
            node["guid"] = Guid.NewGuid().ToString();

            // Recurse if folder
            if (node["type"]?.ToString() == "folder" && node["children"] is JsonArray children)
            {
                foreach (var child in children)
                {
                    ResetBookmarkMetadata(child, ref idCounter);
                }
            }
        }

        /// <summary>
        /// Step 5: The core logic. Merges Chrome bookmarks into Edge JSON structure.
        /// </summary>
        private void MergeBookmarks(List<string> chromeProfilePaths, string edgeProfilePath)
        {
            WriteLogToFile("INFO", "Starting bookmark merge process...");

            // Load Edge JSON (or create empty structure if missing)
            string edgeFile = Path.Combine(edgeProfilePath, BookmarksFileName);
            JsonNode? edgeRoot;
            
            if (File.Exists(edgeFile))
            {
                string jsonContent = File.ReadAllText(edgeFile);
                edgeRoot = JsonNode.Parse(jsonContent);
            }
            else
            {
                // Minimal valid structure if Edge has no bookmarks yet
                edgeRoot = JsonNode.Parse("{\"roots\":{\"bookmark_bar\":{\"children\":[],\"type\":\"folder\"},\"other\":{\"children\":[],\"type\":\"folder\"},\"synced\":{\"children\":[],\"type\":\"folder\"}},\"version\":1}");
            }

            int idCounter = InitialIdCounter; // Start high to avoid conflicts

            foreach (var chromePath in chromeProfilePaths)
            {
                string chromeFile = Path.Combine(chromePath, BookmarksFileName);
                string chromeJson = File.ReadAllText(chromeFile);
                var chromeRoot = JsonNode.Parse(chromeJson);
                string profileName = new DirectoryInfo(chromePath).Name;

                // Create container folder for this profile
                var profileFolder = new JsonObject
                {
                    ["date_added"] = (DateTime.UtcNow.ToFileTimeUtc() / 10).ToString(),
                    ["date_modified"] = (DateTime.UtcNow.ToFileTimeUtc() / 10).ToString(),
                    ["guid"] = Guid.NewGuid().ToString(),
                    ["id"] = "0", // Will be reset
                    ["name"] = $"{ChromeImportPrefix}{profileName}",
                    ["type"] = "folder",
                    ["children"] = new JsonArray()
                };

                // Extract roots from Chrome
                var roots = chromeRoot?["roots"];
                if (roots != null)
                {
                    var targetChildren = profileFolder["children"]!.AsArray();

                    string[] keys = { "bookmark_bar", "other", "synced" };

                    foreach (var key in keys)
                    {
                        if (roots[key]?["children"] is JsonArray children)
                        {
                            // Clone nodes to detach from original parent
                            var clonedChildren = JsonNode.Parse(children.ToJsonString())!.AsArray();
                            foreach (var child in clonedChildren)
                            {
                                targetChildren.Add(child?.DeepClone()); // Deep clone to be safe
                            }
                        }
                    }
                }

                // Reset metadata for the new tree
                ResetBookmarkMetadata(profileFolder, ref idCounter);

                // Insert into Edge Bookmark Bar (at the top)
                var edgeBar = edgeRoot?["roots"]?["bookmark_bar"]?["children"]?.AsArray();
                if (edgeBar != null)
                {
                    edgeBar.Insert(0, profileFolder);
                }
            }

            // Update Edge Timestamps (Webkit format: microseconds since 1601)
            long syncTimestamp = DateTime.UtcNow.ToFileTimeUtc() / 10;
            if (edgeRoot?["roots"]?["bookmark_bar"] is JsonNode bar)
                bar["date_modified"] = syncTimestamp.ToString();
            
            if (edgeRoot?["roots"]?["other"] is JsonNode other)
                other["date_modified"] = syncTimestamp.ToString();

            // Remove checksum to force Edge to recalculate it
            if (edgeRoot?.AsObject().ContainsKey("checksum") == true)
            {
                edgeRoot.AsObject().Remove("checksum");
            }

            // Save
            var options = new JsonSerializerOptions { WriteIndented = false };
            File.WriteAllText(edgeFile, edgeRoot?.ToJsonString(options));
            WriteLogToFile("INFO", "Merged bookmarks saved to Edge profile.");
        }

        /// <summary>
        /// Step 6: Validates that the migration actually wrote the data.
        /// </summary>
        private void TestMigration(string edgeProfilePath)
        {
            string edgeFile = Path.Combine(edgeProfilePath, BookmarksFileName);
            string content = File.ReadAllText(edgeFile);
            var root = JsonNode.Parse(content);

            var children = root?["roots"]?["bookmark_bar"]?["children"]?.AsArray();
            bool found = false;

            if (children != null)
            {
                foreach (var child in children)
                {
                    if (child?["name"]?.ToString().StartsWith(ChromeImportPrefix) == true)
                    {
                        found = true;
                        break;
                    }
                }
            }

            if (!found)
            {
                throw new Exception("Validation failed: Migrated folders not found in target file.");
            }
            WriteLogToFile("INFO", "Validation passed.");
        }

        /// <summary>
        /// Step 7: Restores original files from backup in case of error.
        /// </summary>
        private void InvokeRollback(Exception ex)
        {
            WriteLogToFile("ERROR", $"Initiating Rollback due to: {ex.Message}");

            if (string.IsNullOrEmpty(_backupFolderPath)) return;

            // Restore Edge
            string edgeBackup = Path.Combine(_backupFolderPath, EdgeFolderName, BookmarksFileName);
            string? edgeProfile = GetEdgeTargetProfile();

            if (edgeProfile != null)
            {
                string target = Path.Combine(edgeProfile, BookmarksFileName);
                if (File.Exists(edgeBackup))
                {
                    File.Copy(edgeBackup, target, true);
                    WriteLogToFile("INFO", "Rollback: Edge bookmarks restored.");
                }
                else if (File.Exists(target))
                {
                    // If we created a file but didn't have a backup (fresh edge), delete the corrupt one
                    File.Delete(target);
                    WriteLogToFile("INFO", "Rollback: Created Edge bookmarks file deleted (no backup existed).");
                }
            }

            // Chrome files are strictly read-only in this app, so no need to restore them,
            // but logic could be added here if we modified them.
        }

        #endregion

        private async void BtnCloseBrowsers_Click(object sender, RoutedEventArgs e)
        {
            WriteLogToFile("WARN", "User requested to close browsers.");
            
            BtnCloseBrowsers.IsEnabled = false;
            DeMessageText.Text = "Browser werden geschlossen...";
            EnMessageText.Text = "Closing browsers...";
            SetMessageState("Normal");

            await Task.Run(() =>
            {
                foreach (var process in Process.GetProcessesByName("chrome"))
                {
                    try
                    {
                        process.Kill();
                    }
                    catch
                    {
                        // Ignore processes we don't have access to
                    }
                }
                foreach (var process in Process.GetProcessesByName("msedge"))
                {
                    try
                    {
                        process.Kill();
                    }
                    catch
                    {
                        // Ignore processes we don't have access to
                    }
                }
            });

            await Task.Delay(BrowserCloseWaitTimeMs); // Wait for processes to fully exit
            await CheckBrowserProcessesAsync();
        }

        private void BtnCloseApp_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}