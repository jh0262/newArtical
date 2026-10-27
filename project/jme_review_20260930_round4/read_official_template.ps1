$ErrorActionPreference = 'Stop'
$templateRoot = Join-Path $PSScriptRoot 'journal_sources'
$templatePath = Join-Path $templateRoot 'official_manuscript_template.doc'
$templateWord = $null
$templateDoc = $null
try {
    $templateWord = New-Object -ComObject Word.Application
    $templateWord.Visible = $false
    $templateWord.DisplayAlerts = 0
    $templateWord.AutomationSecurity = 3
    $templateDoc = $templateWord.Documents.Open($templatePath, $false, $true, $false)
    [System.IO.File]::WriteAllText((Join-Path $templateRoot 'official_template_text.txt'), $templateDoc.Content.Text, [System.Text.UTF8Encoding]::new($false))
    $templateSections = @()
    foreach ($templateSection in $templateDoc.Sections) {
        $templateSetup = $templateSection.PageSetup
        $templateSections += [PSCustomObject]@{
            PageWidthPt = $templateSetup.PageWidth
            PageHeightPt = $templateSetup.PageHeight
            TopMarginPt = $templateSetup.TopMargin
            BottomMarginPt = $templateSetup.BottomMargin
            LeftMarginPt = $templateSetup.LeftMargin
            RightMarginPt = $templateSetup.RightMargin
            Columns = $templateSetup.TextColumns.Count
        }
    }
    $templateInfo = [PSCustomObject]@{ Pages = $templateDoc.ComputeStatistics(2); Sections = $templateSections; ReadOnly = $templateDoc.ReadOnly; MacrosDisabled = ($templateWord.AutomationSecurity -eq 3) }
    $templateInfo | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $templateRoot 'official_template_layout.json') -Encoding utf8
    Write-Output ($templateInfo | ConvertTo-Json -Depth 5)
} finally {
    if ($null -ne $templateDoc) { $templateDoc.Close(0) }
    if ($null -ne $templateWord) { $templateWord.Quit() }
}
