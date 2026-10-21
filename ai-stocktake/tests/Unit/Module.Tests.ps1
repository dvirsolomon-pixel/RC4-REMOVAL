Describe 'AIStocktake module' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    It 'has a valid manifest targeting PowerShell 5.1 for Desktop and Core' {
        $m = Test-ModuleManifest -Path $script:AISManifest -ErrorAction Stop
        $m.Name | Should -Be 'AIStocktake'
        $m.PowerShellVersion | Should -Be ([version]'5.1')
        $m.CompatiblePSEditions | Should -Contain 'Desktop'
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }

    It 'exports exactly the public functions' {
        $exported = @((Get-Module AIStocktake).ExportedFunctions.Keys | Sort-Object)
        $public = @(Get-ChildItem (Join-Path $script:AISRepoRoot 'src/AIStocktake/Public') -Filter *.ps1 | ForEach-Object BaseName | Sort-Object)
        $exported | Should -Be $public
        $exported | Should -Contain 'Invoke-AISScan'
        $exported | Should -Contain 'Get-AISCollector'
    }

    It 'every public function name uses the AIS prefix and an approved verb' {
        $verbs = @(Get-Verb | ForEach-Object Verb)
        foreach ($name in (Get-Module AIStocktake).ExportedFunctions.Keys) {
            $parts = $name -split '-', 2
            $verbs | Should -Contain $parts[0]
            $parts[1] | Should -Match '^AIS[A-Z]'
        }
    }

    It 'reads the agent version from the manifest' {
        $v = InModuleScope AIStocktake { $script:AISAgentVersion }
        $v | Should -Be ((Import-PowerShellDataFile $script:AISManifest).ModuleVersion)
    }

    It 'contains no network cmdlets in the scan code' {
        $src = Join-Path $script:AISRepoRoot 'src'
        $hits = Get-ChildItem $src -Recurse -Include *.ps1, *.psm1 | Select-String -Pattern 'Invoke-WebRequest|Invoke-RestMethod|Net\.WebClient|HttpClient|Net\.Sockets'
        $hits | Should -BeNullOrEmpty
    }
}
