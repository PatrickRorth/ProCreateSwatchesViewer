# Load required .NET assemblies
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Function to extract and parse Swatches.json from .swatches file
function Get-SwatchesColors {
    param (
        [string]$swatchesFilePath
    )

    # Create a temporary directory to extract the .swatches file
    $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
    [System.IO.Directory]::CreateDirectory($tempDir)

    try {
        # Extract the .swatches file
        [System.IO.Compression.ZipFile]::ExtractToDirectory($swatchesFilePath, $tempDir)

        # Read and parse the Swatches.json file
        $swatchesJsonPath = [System.IO.Path]::Combine($tempDir, "Swatches.json")
        if (-Not (Test-Path $swatchesJsonPath)) {
            throw "Swatches.json not found in the .swatches file."
        }
        $swatchesData = Get-Content -Path $swatchesJsonPath -Raw | ConvertFrom-Json

        if (-Not $swatchesData.swatches) {
            throw "Invalid Swatches.json format."
        }
    }
    catch {
        Write-Error "Failed to read and parse the .swatches file: $_"
        return $null
    }
    finally {
        # Clean up the temporary directory
        Remove-Item -Recurse -Force $tempDir
    }

    return $swatchesData
}

# Function to create and display an image with the swatches colors
function Show-SwatchesColors {
    param (
        [string]$swatchesFilePath
    )

    $swatchesData = Get-SwatchesColors -swatchesFilePath $swatchesFilePath

    if (-Not $swatchesData) {
        return
    }

    # Define image dimensions
    $circleDiameter = 50
    $spacing = 10
    $columns = 5
    $colorCount = $swatchesData.swatches.Count
    $rows = [math]::Ceiling($colorCount / $columns)
    $imageWidth = [math]::Min($colorCount, $columns) * ($circleDiameter + $spacing) + $spacing
    $imageHeight = $rows * ($circleDiameter + $spacing) + $spacing

    # Create a new image
    $bitmap = New-Object System.Drawing.Bitmap $imageWidth, $imageHeight
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)

    # Draw the circles with the swatches colors
    for ($i = 0; $i -lt $colorCount; $i++) {
        $colorData = $swatchesData.swatches[$i]
        if (-Not $colorData.components) {
            Write-Error "Invalid color components at index $i"
            continue
        }
        $components = $colorData.components
        if ($components.Count -lt 3) {
            Write-Error "Insufficient color components at index $i"
            continue
        }
        $color = [System.Drawing.Color]::FromArgb(
            [int]($components[0] * 255),
            [int]($components[1] * 255),
            [int]($components[2] * 255)
        )

        $x = ($i % $columns) * ($circleDiameter + $spacing) + $spacing
        $y = [math]::Floor($i / $columns) * ($circleDiameter + $spacing) + $spacing
        $brush = New-Object System.Drawing.SolidBrush $color
        $graphics.FillEllipse($brush, $x, $y, $circleDiameter, $circleDiameter)
        $brush.Dispose()
    }

    # Create a form to display the image
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Swatches Colors"
    $form.Width = $imageWidth + 16
    $form.Height = $imageHeight + 39

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = $bitmap
    $pictureBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $form.Controls.Add($pictureBox)

    $form.ShowDialog()
}

# Create the main GUI form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Swatches Viewer"
$form.Width = 300
$form.Height = 100

# Create a "Browse" button
$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse"
$browseButton.Width = 100
$browseButton.Height = 30
$browseButton.Top = 20
$browseButton.Left = 100

# Add a click event to the "Browse" button
$browseButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Swatches files (*.swatches)|*.swatches"
    $openFileDialog.Title = "Select a Swatches File"

    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $swatchesFilePath = $openFileDialog.FileName
        Show-SwatchesColors -swatchesFilePath $swatchesFilePath
    }
})

# Add the "Browse" button to the form
$form.Controls.Add($browseButton)

# Show the main form
$form.ShowDialog()
