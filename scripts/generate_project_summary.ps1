# Flutter Project Structure Analyzer
# Витягує корисну інформацію про структуру проекту

$excludedSuffixes = @('.g.dart', '.freezed.dart', '.part.dart')
$excludedFolders = @('\.git', '\.dart_tool', 'build', 'android', 'ios', 'windows', 'linux', 'macos', 'web')
$outputFile = 'flutter_project_map.txt'

# Видаляємо старий файл
Remove-Item $outputFile -ErrorAction SilentlyContinue

# Функція для витягування корисної інформації
function Extract-DartInfo {
    param($filePath)
    
    $content = Get-Content $filePath -Raw
    $lines = $content -split "`n"
    
    $info = @{
        Imports = @()
        Classes = @()
        Methods = @()
        Properties = @()
        Enums = @()
        Extensions = @()
        Mixins = @()
        Constants = @()
    }
    
    $currentClass = ''
    $braceLevel = 0
    $inComment = $false
    
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        
        # Пропускаємо коментарі
        if ($trimmed.StartsWith('//') -or $trimmed.StartsWith('/*') -or $trimmed.StartsWith('*')) {
            continue
        }
        
        # Imports/Exports
        if ($trimmed -match '^(import|export|part)\s+') {
            $info.Imports += $trimmed
        }
        
        # Classes
        elseif ($trimmed -match '^(abstract\s+)?class\s+(\w+)') {
            $className = $matches[2]
            $info.Classes += $trimmed
            $currentClass = $className
        }
        
        # Enums
        elseif ($trimmed -match '^enum\s+(\w+)') {
            $info.Enums += $trimmed
        }
        
        # Extensions
        elseif ($trimmed -match '^extension\s+(\w+)\s+on\s+(.+)') {
            $info.Extensions += $trimmed
        }
        
        # Mixins
        elseif ($trimmed -match '^mixin\s+(\w+)') {
            $info.Mixins += $trimmed
        }
        
        # Methods/Functions
        elseif ($trimmed -match '^(static\s+)?(Future<.+?>|Stream<.+?>|void|int|double|String|bool|List<.+?>|Map<.+?>|\w+)\s+(\w+)\s*\(') {
            $methodInfo = $trimmed -replace '\s*\{.*$', ''
            if ($currentClass) {
                $methodInfo = "  $methodInfo"
            }
            $info.Methods += $methodInfo
        }
        
        # Properties/Fields
        elseif ($trimmed -match '^(static\s+)?(final\s+|const\s+)?(late\s+)?(\w+\??)\s+(\w+)\s*[=;]') {
            $propertyInfo = $trimmed -replace '\s*=.*$', ''
            if ($currentClass) {
                $propertyInfo = "  $propertyInfo"
            }
            $info.Properties += $propertyInfo
        }
        
        # Constants
        elseif ($trimmed -match '^(static\s+)?const\s+(\w+)\s+(\w+)\s*=') {
            $constantInfo = $trimmed -replace '\s*=.*$', ''
            $info.Constants += $constantInfo
        }
        
        # Getters/Setters
        elseif ($trimmed -match '^\w+\s+get\s+\w+') {
            $getterInfo = $trimmed -replace '\s*=>.*$', ''
            if ($currentClass) {
                $getterInfo = "  $getterInfo"
            }
            $info.Methods += $getterInfo
        }
        
        # Завершення класу
        if ($trimmed -eq '}' -and $currentClass) {
            $currentClass = ''
        }
    }
    
    return $info
}

# Отримуємо pubspec.yaml для залежностей
$pubspecPath = 'pubspec.yaml'
if (Test-Path $pubspecPath) {
    Add-Content $outputFile '==== DEPENDENCIES ===='
    $pubspecContent = Get-Content $pubspecPath
    $inDependencies = $false
    
    foreach ($line in $pubspecContent) {
        if ($line.Trim() -eq 'dependencies:') {
            $inDependencies = $true
            continue
        }
        if ($inDependencies) {
            if ($line.StartsWith('  ') -and $line.Trim() -ne '') {
                Add-Content $outputFile $line.Trim()
            } elseif (-not $line.StartsWith('  ')) {
                $inDependencies = $false
            }
        }
    }
    Add-Content $outputFile ''
}

# Аналізуємо Dart файли
Get-ChildItem -Recurse -Filter *.dart -Path .\lib\ | Where-Object {
    $file = $_.FullName
    
    # Перевіряємо виключені суфікси
    foreach ($suffix in $excludedSuffixes) {
        if ($file.EndsWith($suffix)) { return $false }
    }
    
    # Перевіряємо виключені папки
    foreach ($folder in $excludedFolders) {
        if ($file -match $folder) { return $false }
    }
    
    return $true
} | ForEach-Object {
    $filePath = $_.FullName
    $relativePath = $filePath.Replace((Get-Location).Path, '').TrimStart('\')
    
    Write-Host "Обробляється: $relativePath"
    
    $info = Extract-DartInfo $filePath
    
    # Записуємо інформацію лише якщо є корисний контент
    if ($info.Classes.Count -gt 0 -or $info.Methods.Count -gt 0 -or $info.Enums.Count -gt 0 -or $info.Extensions.Count -gt 0 -or $info.Mixins.Count -gt 0) {
        Add-Content $outputFile "`n==== $relativePath ===="
        
        # Imports (тільки основні)
        if ($info.Imports.Count -gt 0) {
            $mainImports = $info.Imports | Where-Object { 
                $_ -match 'package:' -or $_ -match 'dart:' -or $_ -match '\.\./.*\.dart'
            }
            if ($mainImports.Count -gt 0) {
                Add-Content $outputFile "`n📦 IMPORTS:"
                foreach ($import in $mainImports) {
                    Add-Content $outputFile "  $import"
                }
            }
        }
        
        # Classes
        if ($info.Classes.Count -gt 0) {
            Add-Content $outputFile "`n🏗️ CLASSES:"
            foreach ($class in $info.Classes) {
                Add-Content $outputFile "  $class"
            }
        }
        
        # Enums
        if ($info.Enums.Count -gt 0) {
            Add-Content $outputFile "`n🔢 ENUMS:"
            foreach ($enum in $info.Enums) {
                Add-Content $outputFile "  $enum"
            }
        }
        
        # Extensions
        if ($info.Extensions.Count -gt 0) {
            Add-Content $outputFile "`n⚡ EXTENSIONS:"
            foreach ($extension in $info.Extensions) {
                Add-Content $outputFile "  $extension"
            }
        }
        
        # Mixins
        if ($info.Mixins.Count -gt 0) {
            Add-Content $outputFile "`n🔧 MIXINS:"
            foreach ($mixin in $info.Mixins) {
                Add-Content $outputFile "  $mixin"
            }
        }
        
        # Methods (тільки публічні)
        if ($info.Methods.Count -gt 0) {
            $publicMethods = $info.Methods | Where-Object { -not $_.Contains('_') }
            if ($publicMethods.Count -gt 0) {
                Add-Content $outputFile "`n⚙️ METHODS:"
                foreach ($method in $publicMethods) {
                    Add-Content $outputFile "  $method"
                }
            }
        }
        
        # Properties (тільки публічні)
        if ($info.Properties.Count -gt 0) {
            $publicProperties = $info.Properties | Where-Object { -not $_.Contains('_') }
            if ($publicProperties.Count -gt 0) {
                Add-Content $outputFile "`n🏷️ PROPERTIES:"
                foreach ($property in $publicProperties) {
                    Add-Content $outputFile "  $property"
                }
            }
        }
        
        # Constants
        if ($info.Constants.Count -gt 0) {
            Add-Content $outputFile "`n💎 CONSTANTS:"
            foreach ($constant in $info.Constants) {
                Add-Content $outputFile "  $constant"
            }
        }
    }
}

Write-Host "`n✅ Аналіз завершено! Результат збережено у $outputFile"