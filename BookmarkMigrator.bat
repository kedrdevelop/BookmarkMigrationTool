<# :
@echo off
powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content '%~f0' -Encoding UTF8 -Raw)))"
exit /b
#>

try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- XAML Definition ---
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Chrome to Edge Bookmark Migrator" Height="650" Width="700"
        Background="#1C1B1F" Foreground="#E6E1E5"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#A8C7FA"/>
            <Setter Property="Foreground" Value="#062E6F"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="Medium"/>
            <Setter Property="Padding" Value="24,12"/>
            <Setter Property="Margin" Value="0,32,0,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="20" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Opacity" Value="0.9"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.38"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Border Background="#28262A" CornerRadius="16" Padding="32" 
                VerticalAlignment="Center" HorizontalAlignment="Center" MaxWidth="550">
            <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                <StackPanel HorizontalAlignment="Center">
                
                <TextBlock Text="Bookmark Migrator" FontSize="28" FontWeight="SemiBold" 
                           Foreground="#E6E1E5" Margin="0,0,0,24" HorizontalAlignment="Center"/>

                <Border x:Name="MessageContainer" CornerRadius="12" Padding="16" Background="Transparent">
                    <StackPanel>
                        <TextBlock x:Name="DeMessageText" FontSize="16" Foreground="#E6E1E5" 
                                   TextWrapping="Wrap" TextAlignment="Center" Text="System wird überprüft..."/>

                        <Border x:Name="MessageDivider" Height="1" Background="#49454F" Margin="40,12,40,12"/>

                        <TextBlock x:Name="EnMessageText" FontSize="14" Foreground="#CAC4D0" 
                                   TextWrapping="Wrap" TextAlignment="Center" Text="Checking system..."/>
                    </StackPanel>
                </Border>

                <Border x:Name="ActionRequiredContainer" Background="#332D16" CornerRadius="12" Padding="16" Margin="0,16,0,0" Visibility="Collapsed">
                    <StackPanel>
                        <TextBlock x:Name="DeActionText" FontSize="14" FontWeight="Medium" Foreground="#EAE1B4" TextWrapping="Wrap" TextAlignment="Center"/>
                        <Border Height="1" Background="#49454F" Margin="40,12,40,12" Opacity="0.3"/>
                        <TextBlock x:Name="EnActionText" FontSize="13" Foreground="#EAE1B4" TextWrapping="Wrap" TextAlignment="Center" Opacity="0.8"/>
                    </StackPanel>
                </Border>

                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,24,0,0">
                    <Border x:Name="Step1Container" CornerRadius="12" Padding="12,6" BorderThickness="1" BorderBrush="#49454F">
                        <TextBlock x:Name="Step1Text" Text="1. Check" FontSize="12" FontWeight="Medium" Foreground="#49454F"/>
                    </Border>
                    <Border Width="16" Height="1" Background="#49454F" Margin="4,0"/>
                    <Border x:Name="Step2Container" CornerRadius="12" Padding="12,6" BorderThickness="1" BorderBrush="#49454F">
                        <TextBlock x:Name="Step2Text" Text="2. Migrate" FontSize="12" FontWeight="Medium" Foreground="#49454F"/>
                    </Border>
                    <Border Width="16" Height="1" Background="#49454F" Margin="4,0"/>
                    <Border x:Name="Step3Container" CornerRadius="12" Padding="12,6" BorderThickness="1" BorderBrush="#49454F">
                        <TextBlock x:Name="Step3Text" Text="3. Done" FontSize="12" FontWeight="Medium" Foreground="#49454F"/>
                    </Border>
                </StackPanel>

                <StackPanel Orientation="Vertical" HorizontalAlignment="Center">
                    <Button x:Name="BtnCloseBrowsers" Content="Close Browsers" Visibility="Collapsed"/>
                    <Button x:Name="BtnStartMigration" Content="Start Migration" Visibility="Collapsed"/>
                    <Button x:Name="BtnCloseApp" Content="Close" Visibility="Collapsed"/>
                </StackPanel>
                </StackPanel>
            </ScrollViewer>
        </Border>
    </Grid>
</Window>
"@

    # --- Load XAML ---
    $reader = [System.Xml.XmlReader]::Create((New-Object System.IO.StringReader $xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    # --- Map Controls ---
    $DeMessageText = $window.FindName("DeMessageText")
    $EnMessageText = $window.FindName("EnMessageText")
    $MessageContainer = $window.FindName("MessageContainer")
    $ActionRequiredContainer = $window.FindName("ActionRequiredContainer")
    $DeActionText = $window.FindName("DeActionText")
    $EnActionText = $window.FindName("EnActionText")
    $Step1Container = $window.FindName("Step1Container")
    $Step1Text = $window.FindName("Step1Text")
    $Step2Container = $window.FindName("Step2Container")
    $Step2Text = $window.FindName("Step2Text")
    $Step3Container = $window.FindName("Step3Container")
    $Step3Text = $window.FindName("Step3Text")
    $BtnCloseBrowsers = $window.FindName("BtnCloseBrowsers")
    $BtnStartMigration = $window.FindName("BtnStartMigration")
    $BtnCloseApp = $window.FindName("BtnCloseApp")

    # --- Constants & State ---
    $LogFileBaseName = "migration_log.txt"
    $LogFileName = Join-Path $env:TEMP $LogFileBaseName
    $BackupRootFolderName = "BookmarksBackup"
    $ChromeFolderName = "Chrome"
    $EdgeFolderName = "Edge"
    $BookmarksFileName = "Bookmarks"
    $DefaultProfileName = "Default"
    $ProfileFolderPrefix = "Profile"
    $ChromeImportPrefix = "Chrome_"
    $InitialIdCounter = 100000
    
    $script:backupFolderPath = ""
    $script:logFilePath = ""

    # --- Helper Functions ---

    function udf_WriteLog {
        param($level, $message)
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [$level] $message`r`n"
            $targetFile = if (-not [string]::IsNullOrEmpty($script:logFilePath)) { $script:logFilePath } else { $LogFileName }
            Add-Content -Path $targetFile -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
    }

    function udf_SetMessageState {
        param($state)
        if ($state -eq "Warning") {
            $MessageContainer.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#332D16")
            $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E6C762")
            $DeMessageText.Foreground = $brush
            $EnMessageText.Foreground = $brush
        } elseif ($state -eq "Error") {
            $MessageContainer.Background = [System.Windows.Media.Brushes]::Transparent
            $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F2B8B5")
            $DeMessageText.Foreground = $brush
            $EnMessageText.Foreground = $brush
        } elseif ($state -eq "Success") {
            $MessageContainer.Background = [System.Windows.Media.Brushes]::Transparent
            $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#B7F397")
            $DeMessageText.Foreground = $brush
            $EnMessageText.Foreground = $brush
        } elseif ($state -eq "InProgress") {
            $MessageContainer.Background = [System.Windows.Media.Brushes]::Transparent
            $brush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A8C7FA")
            $DeMessageText.Foreground = $brush
            $EnMessageText.Foreground = $brush
        } else {
            $MessageContainer.Background = [System.Windows.Media.Brushes]::Transparent
            $DeMessageText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E6E1E5")
            $EnMessageText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#CAC4D0")
        }
    }

    function udf_UpdateStepper {
        param($step)
        $activeBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#A8C7FA")
        $activeTextBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#062E6F")
        $doneBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#66BB6A")
        $futureBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#49454F")

        # Reset
        $Step1Container.Background = [System.Windows.Media.Brushes]::Transparent; $Step1Container.BorderBrush = $futureBrush; $Step1Text.Foreground = $futureBrush
        $Step2Container.Background = [System.Windows.Media.Brushes]::Transparent; $Step2Container.BorderBrush = $futureBrush; $Step2Text.Foreground = $futureBrush
        $Step3Container.Background = [System.Windows.Media.Brushes]::Transparent; $Step3Container.BorderBrush = $futureBrush; $Step3Text.Foreground = $futureBrush

        if ($step -eq 1) {
            $Step1Container.Background = $activeBrush; $Step1Container.BorderBrush = $activeBrush; $Step1Text.Foreground = $activeTextBrush
        } elseif ($step -eq 2) {
            $Step1Container.BorderBrush = $doneBrush; $Step1Text.Foreground = $doneBrush
            $Step2Container.Background = $activeBrush; $Step2Container.BorderBrush = $activeBrush; $Step2Text.Foreground = $activeTextBrush
        } elseif ($step -eq 3) {
            $Step1Container.BorderBrush = $doneBrush; $Step1Text.Foreground = $doneBrush
            $Step2Container.BorderBrush = $doneBrush; $Step2Text.Foreground = $doneBrush
            $Step3Container.Background = $activeBrush; $Step3Container.BorderBrush = $activeBrush; $Step3Text.Foreground = $activeTextBrush
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    # --- Logic Functions ---

    function udf_CheckBrowserProcesses {
        udf_WriteLog "INFO" "Checking browser processes..."
        $chrome = Get-Process chrome -ErrorAction SilentlyContinue
        $edge = Get-Process msedge -ErrorAction SilentlyContinue
        
        if ($chrome -or $edge) {
            $DeMessageText.Text = "Browser laufen derzeit. Bitte speichern Sie Ihre Arbeit, bevor Sie schließen."
            $EnMessageText.Text = "Browsers are currently running. Please save your work before closing."
            udf_SetMessageState "Warning"
            udf_UpdateStepper 1
            
            $BtnCloseBrowsers.Visibility = "Visible"
            $BtnStartMigration.Visibility = "Collapsed"
            $BtnCloseApp.Visibility = "Collapsed"
        } else {
            $DeMessageText.Text = "Bereit zum Migrieren der Lesezeichen von Chrome zu Edge."
            $EnMessageText.Text = "Ready to migrate bookmarks from Chrome to Edge."
            udf_SetMessageState "Normal"
            udf_UpdateStepper 2
            
            $BtnCloseBrowsers.Visibility = "Collapsed"
            $BtnStartMigration.Visibility = "Visible"
            $BtnCloseApp.Visibility = "Collapsed"
        }
    }

    function udf_InitializeBackupFolder {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $script:backupFolderPath = Join-Path $desktop "$BackupRootFolderName\$timestamp`_Migration"
        
        New-Item -Path "$script:backupFolderPath\$ChromeFolderName" -ItemType Directory -Force | Out-Null
        New-Item -Path "$script:backupFolderPath\$EdgeFolderName" -ItemType Directory -Force | Out-Null
        
        $newLogPath = Join-Path $script:backupFolderPath $LogFileBaseName
        
        if (Test-Path -Path $LogFileName) {
            Move-Item -Path $LogFileName -Destination $newLogPath -Force -ErrorAction SilentlyContinue
        }
        
        $script:logFilePath = $newLogPath
        udf_WriteLog "INFO" "Backup folder created at: $script:backupFolderPath"
    }

    function udf_GetChromeProfiles {
        $profiles = @()
        $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
        $chromeUserData = Join-Path $localAppData "Google\Chrome\User Data"
        
        udf_WriteLog "INFO" "Scanning for Chrome profiles in: $chromeUserData"
        
        if (Test-Path $chromeUserData) {
            $dirs = Get-ChildItem -Path $chromeUserData -Directory
            foreach ($dir in $dirs) {
                udf_WriteLog "INFO" "Checking directory: $($dir.Name)"
                # Exclude system folders that do not contain valid user bookmarks
                if ($dir.Name -ne "System Profile" -and $dir.Name -ne "Guest Profile") {
                    $bookmarksPath = Join-Path $dir.FullName $BookmarksFileName
                    if (Test-Path $bookmarksPath) {
                        $profiles += $dir.FullName
                        udf_WriteLog "INFO" "Found valid Chrome profile with Bookmarks: $($dir.Name)"
                    } else {
                        udf_WriteLog "INFO" "Skipped: No Bookmarks file in $($dir.Name)"
                    }
                } else {
                    udf_WriteLog "INFO" "Skipped system directory: $($dir.Name)"
                }
            }
        } else {
            udf_WriteLog "WARN" "Chrome User Data directory not found at $chromeUserData"
        }
        
        udf_WriteLog "INFO" "Total valid Chrome profiles identified: $($profiles.Count)"
        return $profiles
    }

    function udf_GetEdgeTargetProfile {
        $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
        $edgeUserData = Join-Path $localAppData "Microsoft\Edge\User Data"
        
        if (Test-Path $edgeUserData) {
            $dirs = Get-ChildItem -Path $edgeUserData -Directory | Where-Object {
                $_.Name -eq $DefaultProfileName -or $_.Name.StartsWith($ProfileFolderPrefix)
            } | Sort-Object CreationTime
            
            if ($dirs) {
                $target = if ($dirs -is [array]) { $dirs[0] } else { $dirs }
                udf_WriteLog "INFO" "Target Edge profile selected: $($target.Name)"
                return $target.FullName
            }
        }
        return $null
    }

    function udf_BackupBookmarks {
        param($chromeProfiles, $edgeProfile)
        
        foreach ($profilePath in $chromeProfiles) {
            $folderName = Split-Path $profilePath -Leaf
            $source = Join-Path $profilePath $BookmarksFileName
            $dest = Join-Path $script:backupFolderPath "$ChromeFolderName\$folderName`_$BookmarksFileName"
            Copy-Item $source $dest -Force
        }

        $edgeSource = Join-Path $edgeProfile $BookmarksFileName
        if (Test-Path $edgeSource) {
            $edgeDest = Join-Path $script:backupFolderPath "$EdgeFolderName\$BookmarksFileName"
            Copy-Item $edgeSource $edgeDest -Force
            udf_WriteLog "INFO" "Edge bookmarks backed up."
        } else {
            udf_WriteLog "WARN" "No existing Edge bookmarks file found."
        }
    }

    function udf_ResetBookmarkMetadata {
        param($node, [ref]$idCounter)
        
        if ($null -eq $node) { return }
        
        $node | Add-Member -MemberType NoteProperty -Name "id" -Value $idCounter.Value.ToString() -Force
        $idCounter.Value++
        $node | Add-Member -MemberType NoteProperty -Name "guid" -Value ([Guid]::NewGuid().ToString()) -Force
        
        if ($node.type -eq "folder" -and $node.children) {
            foreach ($child in $node.children) {
                udf_ResetBookmarkMetadata $child $idCounter
            }
        }
    }

    function udf_CountBookmarks {
        param($node, [ref]$count)
        if ($null -eq $node) { return }
        if ($node.type -eq "url") { $count.Value++ }
        if ($node.type -eq "folder" -and $node.children) {
            foreach ($child in $node.children) { udf_CountBookmarks $child $count }
        }
    }

    function udf_MergeBookmarks {
        param($chromeProfiles, $edgeProfile)
        udf_WriteLog "INFO" "Starting bookmark merge process..."
        
        $edgeFile = Join-Path $edgeProfile $BookmarksFileName
        $edgeJson = $null
        
        if (Test-Path $edgeFile) {
            $edgeJson = Get-Content $edgeFile -Raw | ConvertFrom-Json
        } else {
            $defaultJson = '{"roots":{"bookmark_bar":{"children":[],"type":"folder"},"other":{"children":[],"type":"folder"},"synced":{"children":[],"type":"folder"}},"version":1}'
            $edgeJson = $defaultJson | ConvertFrom-Json
        }

        $idCounter = $InitialIdCounter
        $successfulMerges = 0
        $failedMerges = 0
        $totalBookmarksFound = 0
        $validProfilesToMerge = @()

        # Pass 1: Count bookmarks in all profiles to see if we have anything to migrate
        foreach ($chromePath in $chromeProfiles) {
            try {
                $chromeFile = Join-Path $chromePath $BookmarksFileName
                $chromeJson = Get-Content $chromeFile -Raw | ConvertFrom-Json
                
                $bCount = 0
                if ($chromeJson.roots) {
                    $keys = @("bookmark_bar", "other", "synced")
                    foreach ($key in $keys) {
                        if ($chromeJson.roots.$key) { udf_CountBookmarks $chromeJson.roots.$key ([ref]$bCount) }
                    }
                }
                
                if ($bCount -gt 0) {
                    $totalBookmarksFound += $bCount
                    $validProfilesToMerge += [PSCustomObject]@{ Path = $chromePath; Json = $chromeJson; Name = (Split-Path $chromePath -Leaf); Count = $bCount }
                } else {
                    udf_WriteLog "INFO" "Skipped profile '$(Split-Path $chromePath -Leaf)' because it contains 0 bookmarks."
                }
            } catch {
                udf_WriteLog "ERROR" "Failed to read profile '$($chromePath)': $($_.Exception.Message)"
            }
        }

        if ($totalBookmarksFound -eq 0) {
            udf_WriteLog "INFO" "No actual bookmarks found across any Chrome profile. Skipping Edge modification."
            return $false
        }

        # Pass 2: Merge only profiles that actually have bookmarks
        foreach ($profileData in $validProfilesToMerge) {
            try {
                udf_WriteLog "INFO" "Processing profile: $($profileData.Name)"
                udf_WriteLog "INFO" "Parsed $($profileData.Count) bookmarks from $($profileData.Name)"
                
                # Create container folder
                $profileFolder = [PSCustomObject]@{
                    date_added    = ([string][long]([DateTime]::UtcNow.ToFileTimeUtc() / 10))
                    date_modified = ([string][long]([DateTime]::UtcNow.ToFileTimeUtc() / 10))
                    guid          = [Guid]::NewGuid().ToString()
                    id            = "0"
                    name          = "$ChromeImportPrefix$($profileData.Name)"
                    type          = "folder"
                    children      = @()
                }

                # Extract roots
                $roots = $profileData.Json.roots
                if ($roots) {
                    $keys = @("bookmark_bar", "other", "synced")
                    foreach ($key in $keys) {
                        if ($roots.$key.children) {
                            $profileFolder.children += $roots.$key.children
                        }
                    }
                }

                udf_ResetBookmarkMetadata $profileFolder ([ref]$idCounter)
                
                # Prepend to Edge Bookmark Bar
                if ($null -eq $edgeJson.roots.bookmark_bar.children) {
                    $edgeJson.roots.bookmark_bar | Add-Member -MemberType NoteProperty -Name "children" -Value @() -Force
                }
                $edgeJson.roots.bookmark_bar.children = @($profileFolder) + $edgeJson.roots.bookmark_bar.children
                
                $successfulMerges++
                udf_WriteLog "INFO" "Successfully merged profile: $($profileData.Name)"
            } catch {
                $failedMerges++
                udf_WriteLog "ERROR" "Failed to merge profile '$($profileData.Path)': $($_.Exception.Message)"
            }
        }
        
        udf_WriteLog "INFO" "Migration summary: $successfulMerges successful, $failedMerges failed."
        if ($successfulMerges -eq 0 -and $validProfilesToMerge.Count -gt 0) {
            throw "All valid Chrome profiles failed to merge. Check migration logs for details."
        }
        
        return $true
    }

        # Update Timestamps
        $syncTimestamp = [string][long]([DateTime]::UtcNow.ToFileTimeUtc() / 10)
        
        if ($null -ne $edgeJson.roots.bookmark_bar) {
            $edgeJson.roots.bookmark_bar | Add-Member -MemberType NoteProperty -Name "date_modified" -Value $syncTimestamp -Force
        }
        
        if ($null -ne $edgeJson.roots.other) {
            $edgeJson.roots.other | Add-Member -MemberType NoteProperty -Name "date_modified" -Value $syncTimestamp -Force
        }

        # Remove Checksum (recreate object to remove property cleanly if needed, or just ignore if PS handles it)
        # PSObject.Properties.Remove is tricky with ConvertFrom-Json objects sometimes.
        # Easiest way: Select-Object -ExcludeProperty checksum on the root object? No, root is object.
        # We can just not include it if we reconstruct, but modifying in place is easier.
        if ($edgeJson.PSObject.Properties.Match("checksum").Count -gt 0) {
            $edgeJson.PSObject.Properties.Remove("checksum")
        }

        $mergedJsonString = $edgeJson | ConvertTo-Json -Depth 100 -Compress
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($edgeFile, $mergedJsonString, $utf8NoBom)
        udf_WriteLog "INFO" "Merged bookmarks saved to Edge profile."
    }

    function udf_InvokeRollback {
        param($ex)
        udf_WriteLog "ERROR" "Initiating Rollback due to: $($ex.Message)"
        if ([string]::IsNullOrEmpty($script:backupFolderPath)) { return }
        
        $edgeBackup = Join-Path $script:backupFolderPath "$EdgeFolderName\$BookmarksFileName"
        $edgeProfile = udf_GetEdgeTargetProfile
        
        if ($edgeProfile) {
            $target = Join-Path $edgeProfile $BookmarksFileName
            if (Test-Path $edgeBackup) {
                Copy-Item $edgeBackup $target -Force
                udf_WriteLog "INFO" "Rollback: Edge bookmarks restored."
            } elseif (Test-Path $target) {
                Remove-Item $target -Force
                udf_WriteLog "INFO" "Rollback: Created Edge bookmarks file deleted."
            }
        }
    }

    # --- Event Handlers ---

    $BtnCloseBrowsers.Add_Click({
        $BtnCloseBrowsers.IsEnabled = $false
        $DeMessageText.Text = "Browser werden geschlossen (dies kann einen Moment dauern)..."
        $EnMessageText.Text = "Closing browsers (this may take a moment)..."
        udf_SetMessageState "InProgress"
        [System.Windows.Forms.Application]::DoEvents()

        $maxRetries = 3
        $retryCount = 0
        $browsersClosed = $false

        while ($retryCount -lt $maxRetries -and -not $browsersClosed) {
            $chrome = Get-Process chrome -ErrorAction SilentlyContinue
            $edge = Get-Process msedge -ErrorAction SilentlyContinue
            
            if (-not $chrome -and -not $edge) {
                $browsersClosed = $true
                break
            }

            Get-Process msedge, chrome -ErrorAction SilentlyContinue | ForEach-Object { 
                $_.CloseMainWindow() | Out-Null 
            } 
            
            $sleepCount = 0
            while ($sleepCount -lt 4 -and ($chrome -or $edge)) {
                Start-Sleep -Milliseconds 500
                [System.Windows.Forms.Application]::DoEvents()
                $chrome = Get-Process chrome -ErrorAction SilentlyContinue
                $edge = Get-Process msedge -ErrorAction SilentlyContinue
                if (-not $chrome -and -not $edge) { $browsersClosed = $true; break }
                $sleepCount++
            }
            
            if (-not $browsersClosed) {
                Get-Process msedge, chrome -ErrorAction SilentlyContinue | Stop-Process -Force
                Start-Sleep -Seconds 1
            }
            
            $chrome = Get-Process chrome -ErrorAction SilentlyContinue
            $edge = Get-Process msedge -ErrorAction SilentlyContinue
            if (-not $chrome -and -not $edge) { $browsersClosed = $true }
            
            $retryCount++
        }

        if ($browsersClosed) {
            udf_CheckBrowserProcesses
        } else {
            $DeMessageText.Text = "Browser konnten nicht geschlossen werden. Bitte schliessen Sie diese manuell."
            $EnMessageText.Text = "Could not close browsers. Please close them manually."
            udf_SetMessageState "Error"
            $BtnCloseBrowsers.IsEnabled = $true
            udf_WriteLog "ERROR" "Failed to close browsers after $maxRetries retries."
        }
    })

    $BtnStartMigration.Add_Click({
        $BtnStartMigration.Visibility = "Collapsed"
        $BtnCloseBrowsers.Visibility = "Collapsed"
        $DeMessageText.Text = "Lesezeichen werden migriert..."
        $EnMessageText.Text = "Migrating bookmarks..."
        udf_SetMessageState "InProgress"
        udf_UpdateStepper 2
        [System.Windows.Forms.Application]::DoEvents()

        try {
            udf_WriteLog "INFO" "Starting migration process."
            udf_InitializeBackupFolder
            
            $chromeProfiles = udf_GetChromeProfiles
            $edgeProfile = udf_GetEdgeTargetProfile
            
            if ($chromeProfiles.Count -eq 0) { throw "No Chrome profiles found." }
            if ([string]::IsNullOrEmpty($edgeProfile)) { throw "No Edge profile found." }
            
            udf_BackupBookmarks $chromeProfiles $edgeProfile
            $hasBookmarks = udf_MergeBookmarks $chromeProfiles $edgeProfile
            
            if ($hasBookmarks) {
                # Validation
                $content = Get-Content (Join-Path $edgeProfile $BookmarksFileName) -Raw
                if ($content -notmatch "$ChromeImportPrefix") { throw "Validation failed: Migrated folders not found." }
                
                udf_WriteLog "INFO" "Migration completed successfully."
                udf_UpdateStepper 3
                
                $DeMessageText.Text = "Migration erfolgreich!"
                $EnMessageText.Text = "Migration successful!"
                udf_SetMessageState "Success"
                
                $DeActionText.Text = "Hinweis: Der importierte Ordner erscheint möglicherweise am Ende Ihrer Lesezeichenleiste. Bitte öffnen Sie Edge und ziehen Sie ihn manuell an den Anfang."
                $EnActionText.Text = "Note: The imported folder might appear at the end of your bookmarks bar. Please open Edge and drag it to the beginning manually."
                $ActionRequiredContainer.Visibility = "Visible"
            } else {
                udf_WriteLog "INFO" "No bookmarks were found in any Chrome profile. Migration skipped."
                udf_UpdateStepper 3
                
                $DeMessageText.Text = "Keine Lesezeichen in Chrome gefunden. Migration nicht erforderlich."
                $EnMessageText.Text = "No bookmarks found in Chrome. Migration not required."
                udf_SetMessageState "Success"
            }
            
            $BtnCloseApp.Visibility = "Visible"
            
        } catch {
            udf_InvokeRollback $_.Exception
            $DeMessageText.Text = "Ein Fehler ist aufgetreten. Änderungen wurden rückgängig gemacht.`nFehler: $($_.Exception.Message)`nKontaktieren Sie den Entwickler: viacheslav.kedrov@servier.com"
            $EnMessageText.Text = "An error occurred. Changes have been rolled back.`nError: $($_.Exception.Message)`nContact developer: viacheslav.kedrov@servier.com"
            udf_SetMessageState "Error"
            $BtnCloseApp.Visibility = "Visible"
        }
    })

    $BtnCloseApp.Add_Click({
        $window.Close()
    })

    # --- Startup ---
    $window.Add_Loaded({
        udf_CheckBrowserProcesses
    })

    $window.ShowDialog() | Out-Null

} catch {
    [System.Windows.MessageBox]::Show($_.Exception.ToString(), "Fatal Error")
}