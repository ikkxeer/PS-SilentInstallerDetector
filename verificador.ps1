Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# -------------------------------
# XAML - Interfaz gráfica
# -------------------------------
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Silent Installer Detector"
        Height="420" Width="720"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E"
        FontFamily="Segoe UI">

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Título -->
        <TextBlock Text="Silent Installer Detector"
                   FontSize="26"
                   FontWeight="Bold"
                   Foreground="#00D1FF"
                   Margin="0,0,0,10" />

        <!-- Selector de archivo -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,15">
            <TextBox x:Name="txtFile"
                     Width="500"
                     Height="30"
                     IsReadOnly="True"
                     Background="#2D2D30"
                     Foreground="White"
                     BorderBrush="#3E3E42"
                     Padding="8" />
            <Button x:Name="btnBrowse"
                    Content="Examinar"
                    Width="120"
                    Margin="10,0,0,0"
                    Background="#007ACC"
                    Foreground="White"
                    FontWeight="SemiBold" />
        </StackPanel>

        <!-- Resultado -->
        <GroupBox Grid.Row="2" Header="Resultado"
                  Foreground="#00D1FF"
                  BorderBrush="#3E3E42">
            <TextBox x:Name="txtResult"
                     Background="#252526"
                     Foreground="#DCDCDC"
                     FontSize="14"
                     IsReadOnly="True"
                     TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto"
                     Padding="10" />
        </GroupBox>

        <!-- Barra inferior -->
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
             <Button x:Name="btnAutoTest"
                    Content="Prueba Automática"
                    Width="140"
                    Margin="0,0,10,0"
                    Background="#D19A00"
                    Foreground="White"
                    Visibility="Collapsed"/>
            <Button x:Name="btnCopy"
                    Content="Copiar comando"
                    Width="150"
                    Margin="0,0,10,0"
                    Background="#3A3D41"
                    Foreground="White" />
            <Button x:Name="btnExit"
                    Content="Salir"
                    Width="100"
                    Background="#C74E39"
                    Foreground="White" />
        </StackPanel>

    </Grid>
</Window>
"@

# Cargamos la ventana default
$Reader = (New-Object System.Xml.XmlNodeReader $XAML)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Referencias a controles
$txtFile = $Window.FindName("txtFile")
$txtResult = $Window.FindName("txtResult")
$btnBrowse = $Window.FindName("btnBrowse")
$btnCopy = $Window.FindName("btnCopy")
$btnAutoTest = $Window.FindName("btnAutoTest")
$btnExit = $Window.FindName("btnExit")

# -------------------------------
# Funciones
# -------------------------------
function Detect-InstallerType {
    param ($Path)

    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $bytes = Get-Content $Path -AsByteStream -TotalCount 5000
        }
        else {
            $bytes = Get-Content $Path -Encoding Byte -TotalCount 5000
        }
        $text = [System.Text.Encoding]::ASCII.GetString($bytes)

        if ($text -match "Inno Setup") { return "Inno" }
        if ($text -match "NSIS") { return "NSIS" }
        if ($text -match "InstallShield") { return "InstallShield" }
        if ($text -match "WiX") { return "WiX" }

        return "Unknown"
    }
    catch {
        return "Unknown"
    }
}

function Get-SilentCommand {
    param ($FilePath)

    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $fileName = [System.IO.Path]::GetFileName($FilePath)

    switch ($ext) {
        ".msi" {
            return "msiexec /i `"$fileName`" /qn /norestart"
        }
        ".exe" {
            $type = Detect-InstallerType $FilePath

            switch ($type) {
                "Inno" { return "`"$fileName`" /VERYSILENT /NORESTART" }
                "NSIS" { return "`"$fileName`" /S" }
                "InstallShield" { return "`"$fileName`" /s /v`"/qn`"" }
                "WiX" { return "`"$fileName`" /quiet /norestart" }
                default {
                    return "No se pudo detectar el instalador. Prueba manualmente con: /S, /silent, /quiet, /verysilent"
                }
            }
        }
        default {
            return "Formato no soportado. Selecciona un archivo .msi o .exe"
        }
    }
}

# -------------------------------
# Eventos
# -------------------------------
$btnBrowse.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "Instaladores (*.msi;*.exe)|*.msi;*.exe"

        if ($dialog.ShowDialog() -eq "OK") {
            $txtFile.Text = $dialog.FileName
            $txtResult.Text = "Analizando instalador..."
            $btnAutoTest.Visibility = "Collapsed"

            try {
                $command = Get-SilentCommand $dialog.FileName
                
                if ($command -like "*No se pudo detectar*") {
                    $txtResult.Text = "$command`n`nPuedes intentar la 'Prueba Automática' para buscar switches funcionales."
                    $btnAutoTest.Visibility = "Visible"
                }
                else {
                    $txtResult.Text = "Comando sugerido para instalación silenciosa:`n`n$command"
                }
            }
            catch {
                $txtResult.Text = "Error al analizar el archivo: $_"
            }
        }
    })

$btnAutoTest.Add_Click({
        $filePath = $txtFile.Text
        if (-not (Test-Path $filePath)) { return }
        
        $switches = @("/S", "/silent", "/quiet", "/verysilent", "/qn", "/norestart", "/s", "/q")
        $fileName = [System.IO.Path]::GetFileName($filePath)
        $found = $false

        $txtResult.Text = "Iniciando pruebas automáticas... (Esto puede tardar un poco)`n"

        foreach ($sw in $switches) {
            $txtResult.Text += "`nProbando: $sw ..."
            # Refrescar UI
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                $proc = Start-Process -FilePath $filePath -ArgumentList $sw -PassThru
                Start-Sleep -Seconds 3 # Esperar a que inicialice ventana si la hay
                
                if (-not $proc.HasExited) {
                    $proc.Refresh()
                    
                    # Heurística: Si Main Window Handle es 0, probablemente es silent
                    if ($proc.MainWindowHandle -eq 0) {
                        $proc.Kill()
                        $txtResult.Text = "`n¡EXITO DETECTADO!`n`nEl switch '$sw' parece funcionar (el proceso corrió sin ventana).`n`nComando:`n`"$fileName`" $sw"
                        $found = $true
                        break
                    }
                    else {
                        # Abrió ventana, no es silent
                        $proc.Kill()
                        $txtResult.Text += " (Detectada ventana, fallo)"
                    }
                }
                else {
                    $txtResult.Text += " (Proceso terminó muy rápido)"
                }
            }
            catch {
                $txtResult.Text += " (Error al ejecutar)"
            }
        }

        if (-not $found) {
            $txtResult.Text += "`n`nFin de las pruebas. No se encontró un switch silencioso obvio."
        }
    })

$btnCopy.Add_Click({
        if ($txtResult.Text) {
            [System.Windows.Clipboard]::SetText($txtResult.Text)
        }
    })

$btnExit.Add_Click({
        $Window.Close()
    })

# -------------------------------
# Mostrar ventana
# -------------------------------
$Window.ShowDialog() | Out-Null
