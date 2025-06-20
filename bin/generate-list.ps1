param(
    [array]$PathList = @("app-list.md", "app-list-cn.md")
)

$manifests = Get-ChildItem "$PSScriptRoot\..\bucket"

function A-Test-ScriptPattern {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [string[]]$ScriptSections = @('pre_install', 'post_install', 'pre_uninstall', 'post_uninstall'),

        [string[]]$ScriptProperties = @('installer', 'uninstaller')
    )

    function Test-ObjectForPattern {
        param(
            [PSObject]$Object,
            [string]$SearchPattern
        )

        $found = $false

        foreach ($section in $ScriptSections) {
            if (!$found -and $Object.$section) {
                $found = ($Object.$section -join "`n") -match $SearchPattern
            }
        }

        foreach ($property in $ScriptProperties) {
            if (!$found -and $Object.$property.script) {
                $found = ($Object.$property.script -join "`n") -match $SearchPattern
            }
        }

        return $found
    }

    $patternFound = Test-ObjectForPattern -Object $InputObject -SearchPattern $Pattern

    if (!$patternFound -and $InputObject.architecture) {
        if ($InputObject.architecture.'64bit') {
            $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.'64bit' -SearchPattern $Pattern
        }
        if (!$patternFound -and $InputObject.architecture.'32bit') {
            $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.'32bit' -SearchPattern $Pattern
        }
        if (!$patternFound -and $InputObject.architecture.arm64) {
            $patternFound = Test-ObjectForPattern -Object $InputObject.architecture.arm64 -SearchPattern $Pattern
        }
    }

    return $patternFound
}

function get_static_content($path) {
    $content = Get-Content -Path $path -Encoding UTF8

    $match = $content | Select-String -Pattern "<!-- prettier-ignore-start -->"

    if ($match) {
        $matchLineNumber = ([array]$match.LineNumber)[0]
        $result = $content | Select-Object -First $matchLineNumber
        $result
    }
}


foreach ($path in $PathList) {
    $content = @("|App ($($manifests.Length))|Persist|Tag|Description|", "|:-:|:-:|:-:|-|")

    $isCN = $path -like "*cn*.md"

    foreach ($_ in $manifests) {
        $json = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
        $info = @()

        $app = $_.BaseName

        # homepage
        if ($isCN) {
            $info += "[$app]($($json.homepage) `"点击查看 $($app) 的主页或仓库`")"
        }
        else {
            $info += "[$app]($($json.homepage) `"Click to view the homepage or repository of $($app)`")"
        }

        # persist
        $isPersist = $json.persist
        $isLink = $false

        if (!$isPersist) {
            $isLink = A-Test-ScriptPattern $json '.*(A-New-LinkDirectory)|(A-New-LinkFile).*'
        }
        if ($isLink) {
            if ($isCN) {
                $label = '<code title="' + $app + ' 使用 Link 进行数据持久化">Link</code>'
            }
            else {
                $label = '<code title="' + $app + ' uses Link for data persistence">Link</code>'
            }

            $info += $label
        }
        else {
            if ($isPersist) {
                if ($isCN) {
                    $label = '<code title="' + $app + ' 使用 Scoop 官方的 persist 实现">✔️</code>'
                }
                else {
                    $label = '<code title="' + $app + ' uses Scoop official persist implementation">✔️</code>'
                }
                $info += $label
            }
            else {
                if ($isCN) {
                    $label = '<code title="' + $app + ' 未实现 persist，因为不存在数据或者没有实现的必要">➖</code>'
                }
                else {
                    $label = '<code title="' + $app + ' does not implement persist because there is no data or no need for persist">➖</code>'
                }
                $info += $label
            }
        }

        # Tag
        $tag = @()

        ## version
        # $info += "[v$($json.version)](./bucket/$($_.Name))"
        $title = if ($isCN) { "点击查看 $app 的 manifest json 文件" } else { "Click to view the manifest json file of $app" }
        $tag += '<a href="./bucket/' + $_.Name + '" title="' + $title + '"><img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fabgox%2Fabyss%2Frefs%2Fheads%2Fmain%2Fbucket%2F' + $_.Name + '&query=%24.version&prefix=v&label=%20" alt="version" /></a>'

        ## Msix
        $isMsix = A-Test-ScriptPattern $json '.*A-Add-MsixPackage.*'
        if ($isCN) {
            $label = '<code title="' + $app + ' 通过 Msix 安装，安装目录不在 Scoop 中，Scoop 只管理数据、安装、卸载、更新">Msix</code>'
        }
        else {
            $label = '<code title="' + $app + ' installs using Msix, installation directory is not in Scoop, Scoop only manages data, installation, uninstallation, and updates">Msix</code>'
        }
        $tag += if ($isMsix) { $label }

        ## RequireAdmin
        $RequireAdmin = A-Test-ScriptPattern $json '.*(A-Require-Admin)|(A-New-LinkFile).*'

        $label = if ($isCN) { '<code title="在安装、更新或卸载时需要管理员权限">RequireAdmin</code>' } else { '<code title="Requires administrator permission to install, update, or uninstall">RequireAdmin</code>' }
        $tag += if ($RequireAdmin) { $label }

        ## NoSilentInstall
        $NoSilentInstall = A-Test-ScriptPattern $json '.*A-Install-Exe.*-NoSilent.*'
        $label = if ($isCN) { '<code title="在安装时可能需要用户交互">NoSilentInstall</code>' } else { '<code title="May require user interaction during installation">NoSilentInstall</code>' }
        $tag += if ($NoSilentInstall) { $label }

        ## NoSilentUninstall
        $NoSilentUninstall = A-Test-ScriptPattern $json '.*A-Uninstall-Exe.*-NoSilent.*'
        $label = if ($isCN) { '<code title="在卸载时可能需要用户交互">NoSilentUninstall</code>' } else { '<code title="May require user interaction during uninstallation">NoSilentUninstall</code>' }
        $tag += if ($NoSilentUninstall) { $label }

        ## font
        if (A-Test-ScriptPattern $json '.*A-Add-Font.*') {
            if ($isCN) {
                $label = '<code title="' + $app + ' 是一个字体">Font</code>'
            }
            else {
                $label = '<code title="' + $app + ' is a font">Font</code>'
            }
            $tag += $label
        }

        ## NoUpdate
        if ($isCN) {
            $label = '<code title="Scoop 不会检查它的版本更新，因为 ' + $app + ' 没有配置 autoupdate">NoUpdate</code>'
        }
        else {
            $label = '<code title="Scoop will not check for its version updates, because autoupdate is not configured">NoUpdate</code>'
        }
        $tag += if (!$json.autoupdate) { $label }

        ## PSModule
        if ($isCN) {
            $label = '<code title="' + $app + ' 是一个 Powershell 模块">PSModule</code>'
        }
        else {
            $label = $label = '<code title="' + $app + ' is a Powershell module">PSModule</code>'
        }
        $tag += if ($json.psmodule) { $label }

        $info += $tag -join '<br />'

        ## description
        $description = $json.description -split '(?<=。)(?=[^。]+$)'

        if ($path -like "*cn*.md") {
            $info += $description[0]
        }
        else {
            $info += $description[1]
        }

        $content += "|" + ($info -join "|") + "|"
    }

    (get_static_content $path) + $content + "`n<!-- prettier-ignore-end -->" | Out-File $path -Encoding UTF8 -Force
}
