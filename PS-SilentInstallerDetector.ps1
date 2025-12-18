Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# -------------------------------
# XAML - Interfaz grafica mejorada
# -------------------------------
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Silent Installer Detector"
        Height="500" Width="800"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E"
        FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Estilo para Botones -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                CornerRadius="8" 
                                BorderBrush="#3E3E42" 
                                BorderThickness="1" 
                                Padding="15,8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3E3E42"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#007ACC"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#007ACC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo para TextBox -->
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="Foreground" Value="#F1F1F1"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="Padding" Value="8"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" 
                                CornerRadius="6" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="1">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="25">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Titulo con degradado simulado o color plano vibrante -->
        <TextBlock Text="Silent Installer Detector"
                   FontSize="32"
                   FontWeight="Bold"
                   Foreground="#00A1FF"
                   Margin="0,0,0,20"
                   HorizontalAlignment="Center">
            <TextBlock.Effect>
                <DropShadowEffect Color="Black" BlurRadius="10" ShadowDepth="2" Opacity="0.5"/>
            </TextBlock.Effect>
        </TextBlock>

        <!-- Selector de archivo -->
        <Grid Grid.Row="1" Margin="0,0,0,20">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            
            <TextBox x:Name="txtFile"
                     IsReadOnly="True"
                     Text="Selecciona un ejecutable..." 
                     Foreground="#AAAAAA"/>
            
            <Button x:Name="btnBrowse"
                    Grid.Column="1"
                    Content="Examinar"
                    Width="120"
                    Margin="10,0,0,0"
                    Background="#007ACC"/>
        </Grid>

        <!-- Resultado -->
        <Border Grid.Row="2" 
                Background="#252526" 
                CornerRadius="10" 
                BorderBrush="#3E3E42" 
                BorderThickness="1"
                Padding="15">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Text="Resultado del Analisis" 
                           Foreground="#00D1FF" 
                           FontWeight="SemiBold" 
                           Margin="0,0,0,10"/>
                <TextBox x:Name="txtResult"
                         Grid.Row="1"
                         Background="Transparent"
                         BorderThickness="0"
                         Foreground="#E1E1E1"
                         FontSize="14"
                         IsReadOnly="True"
                         TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto"
                         FontFamily="Consolas" />
            </Grid>
        </Border>

        <!-- Barra inferior -->
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
             <Button x:Name="btnAutoTest"
                    Content="Prueba Automatica"
                    Width="160"
                    Background="#D19A00"
                    Foreground="White"
                    Visibility="Collapsed"/>
                    
            <Button x:Name="btnCopy"
                    Content="Copiar Comando"
                    Width="160"
                    Background="#3A3D41"/>
                    
            <Button x:Name="btnExit"
                    Content="Salir"
                    Width="100"
                    Background="#C74E39"/>
        </StackPanel>

    </Grid>
</Window>
"@

# Cargamos la ventana default
try {
    $Reader = (New-Object System.Xml.XmlNodeReader $XAML)
    $Window = [Windows.Markup.XamlReader]::Load($Reader)
} catch {
    Write-Host "Error cargando XAML: $_"
    exit
}

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
            $bytes = Get-Content $Path -AsByteStream -TotalCount 10000
        }
        else {
            $bytes = Get-Content $Path -Encoding Byte -TotalCount 10000
        }
        $text = [System.Text.Encoding]::ASCII.GetString($bytes)

        # Patrones de deteccion
        if ($text -match "Inno Setup") { return "Inno" }
        if ($text -match "Nullsoft Install System" -or $text -match "NSIS") { return "NSIS" }
        if ($text -match "InstallShield") { return "InstallShield" }
        if ($text -match "WiX") { return "WiX" }
        if ($text -match "Wise") { return "Wise" }
        if ($text -match "Advanced Installer") { return "AdvancedInstaller" }

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
            
            # Mapeo de tipos conocidos a argumentos
            switch ($type) {
                "Inno" { return "`"$fileName`" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" }
                "NSIS" { return "`"$fileName`" /S" }
                "InstallShield" { return "`"$fileName`" /s /v`"/qn`"" }
                "WiX" { return "`"$fileName`" /quiet /norestart" }
                "Wise" { return "`"$fileName`" /s" }
                "AdvancedInstaller" { return "`"$fileName`" /exenoui /qn" }
                default {
                    return "NO_DETECTED"
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
            
            # Estilo visual para indicar carga
            $txtResult.Foreground = "#AAAAAA"
            $txtResult.Text = "Analizando archivo, por favor espere..."
            $btnAutoTest.Visibility = "Collapsed"

            # Pequeno delay para UX
            Start-Sleep -Milliseconds 200

            try {
                $command = Get-SilentCommand $dialog.FileName
                
                if ($command -eq "NO_DETECTED") {
                    $txtResult.Foreground = "#FFD700" # Amarillo dorado
                    $txtResult.Text = "No se pudo detectar la tecnologia del instalador automaticamente.`n`nSe recomienda usar la 'Prueba Automatica' para probar todos los parametros conocidos."
                    $btnAutoTest.Visibility = "Visible"
                }
                elseif ($command -like "Formato no*") {
                    $txtResult.Foreground = "#FF6B6B" # Rojo suave
                    $txtResult.Text = $command
                }
                else {
                    $txtResult.Foreground = "#00D1FF" # Cyan brillante
                    $txtResult.Text = "Tecnologia detectada con exito.`n`nComando sugerido:`n$command"
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
        
        # Lista expandida de argumentos posibles
        $switches = @(
            "/S", 
            "/silent", 
            "/verysilent", 
            "/verysilent /suppressmsgboxes /norestart",
            "/quiet", 
            "/passive", 
            "/qn", 
            "/q", 
            "-q",
            "/s", 
            "/exenoui",
            "/exenoupdates",
            "--mode unattended",
            "/norestart"
        )
        
        $fileName = [System.IO.Path]::GetFileName($filePath)
        $found = $false

        $txtResult.Foreground = "#FFFFFF"
        $txtResult.Text = "Iniciando pruebas automaticas...`nLa ventana puede parpadear o perder foco.`n"

        foreach ($sw in $switches) {
            $txtResult.Text += "`nProbando: $sw ..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                $proc = Start-Process -FilePath $filePath -ArgumentList $sw -PassThru
                
                # Esperamos un poco mas para dar tiempo al proceso de mostrar ventana si la tiene
                Start-Sleep -Seconds 2
                
                if (-not $proc.HasExited) {
                    $proc.Refresh()
                    
                    # Heuristica: Si Main Window Handle es 0, probablemente es silent (sin ventana grafica)
                    if ($proc.MainWindowHandle -eq 0) {
                        $proc.Kill()
                        $txtResult.Foreground = "#00FF7F" # Verde primavera
                        $txtResult.Text = "`n!EXITO DETECTADO!`n`nEl switch '$sw' parece funcionar (el proceso corrio en segundo plano sin ventana).`n`nComando final:`n`"$fileName`" $sw"
                        $found = $true
                        break
                    }
                    else {
                        # Abrio ventana, no es silent
                        $proc.Kill()
                        $txtResult.Text += " [Fallo: Ventana detectada]"
                    }
                }
                else {
                    # Si termina muy rapido puede ser crash o instalacion super rapida (o extraccion)
                    # A veces /S retorna inmediato en wrappers. Comprobaremos ExitCode si es 0
                    if ($proc.ExitCode -eq 0) {
                        $txtResult.Text += " [Posible exito: Termino rapido con codigo 0]"
                    } else {
                        $txtResult.Text += " [Fallo: Termino inmediatamente]"
                    }
                }
            }
            catch {
                $txtResult.Text += " [Error de ejecucion]"
            }
        }

        if (-not $found) {
            $txtResult.Foreground = "#FF6B6B"
            $txtResult.Text += "`n`nFin de las pruebas. No se encontro un switch silencioso estandar."
        }
    })

$btnCopy.Add_Click({
        if ($txtResult.Text) {
            # Extraer solo el comando si es posible, o todo el texto
            # Por simplicidad copiamos todo y notificamos visualmente
            [System.Windows.Clipboard]::SetText($txtResult.Text)
            $originalText = $btnCopy.Content
            $btnCopy.Content = "Copiado!"
            $btnCopy.Background = "#28A745"
            
            $timer = New-Object System.Windows.Forms.Timer
            $timer.Interval = 2000
            $timer.Add_Tick({
                $btnCopy.Content = $originalText
                $btnCopy.Background = "#3A3D41"
                $timer.Stop()
            })
            $timer.Start()
        }
    })

$btnExit.Add_Click({
        $Window.Close()
    })

# -------------------------------
# Mostrar ventana
# -------------------------------
$Window.ShowDialog() | Out-Null
