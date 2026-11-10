# Creates all Robux items (9 Game Passes + 11 Developer Products) for Moonlit Grove through the
# official Roblox Open Cloud API, then writes their IDs into src/config/Products.luau.
#
# Before running:
#   1. Publish the game (LAUNCH-CHECKLIST.md section 1).
#   2. Create an API key (create.roblox.com > Open Cloud > API Keys) with ONLY:
#        game-pass:write and developer-product:write, for this one experience.
#   3. Save the key as plain text in:  E:\Monster-Garden\.roblox-api-key.txt
#      (this file is in .gitignore and is never shared)
#
# Run (PowerShell, in the project folder):
#   powershell -ExecutionPolicy Bypass -File tools\create-robux-items.ps1 -UniverseId 1234567890
#
# Safe to run again: items already created (listed in tools\robux-ids.json) are skipped.
# Afterwards: delete the API key on the website and delete .roblox-api-key.txt.

param(
	[Parameter(Mandatory = $true)][string]$UniverseId
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keyFile = Join-Path $root ".roblox-api-key.txt"
$productsFile = Join-Path $root "src\config\Products.luau"
$resultsFile = Join-Path $PSScriptRoot "robux-ids.json"

if (-not (Test-Path $keyFile)) {
	Write-Host "Save your API key in $keyFile first (see the top of this script)." -ForegroundColor Red
	exit 1
}
$key = (Get-Content $keyFile -Raw).Trim()
if ($key.Length -lt 20) {
	Write-Host "The key in $keyFile looks too short. Paste the whole key." -ForegroundColor Red
	exit 1
}
if ($UniverseId -notmatch '^\d+$') {
	Write-Host "UniverseId must be a number (the Universe ID, not the Place ID)." -ForegroundColor Red
	exit 1
}

# Items: Id = code id in Products.luau, Kind = pass/product
$items = @(
	@{ Id = "pass_plot";        Kind = "pass";    Name = "Extra Plot";          Price = 199; Desc = "+16 farm tiles in an expansion area" },
	@{ Id = "pass_nest";        Kind = "pass";    Name = "Extra Nest Slot";     Price = 149; Desc = "+1 breeding nest slot" },
	@{ Id = "pass_inventory";   Kind = "pass";    Name = "Bigger Inventory";    Price = 149; Desc = "+100 bag space" },
	@{ Id = "pass_autoharvest"; Kind = "pass";    Name = "Auto-Harvest";        Price = 399; Desc = "Auto-harvests ready crops every 10 seconds" },
	@{ Id = "pass_founder";     Kind = "pass";    Name = "Founder Pass";        Price = 499; Desc = "Founder title, creature glow, garden theme and +50 bag space" },
	@{ Id = "pass_shoptheme";   Kind = "pass";    Name = "Shop Stall Themes";   Price = 149; Desc = "Golden shop stall" },
	@{ Id = "pass_grovetheme";  Kind = "pass";    Name = "Spirit Grove Themes"; Price = 199; Desc = "Starlight Spirit Grove" },
	@{ Id = "pass_vipflair";    Kind = "pass";    Name = "Premium Flair";       Price = 99;  Desc = "VIP title" },
	@{ Id = "pass_season";      Kind = "pass";    Name = "Moon Season Premium"; Price = 599; Desc = "Premium track of the Moon Season (cosmetics only)" },
	@{ Id = "dp_rename";        Kind = "product"; Name = "Rename Token";        Price = 25;  Desc = "Rename a creature" },
	@{ Id = "dp_recolor";       Kind = "product"; Name = "Recolor Token";       Price = 49;  Desc = "Change a creature color" },
	@{ Id = "dp_crate1";        Kind = "product"; Name = "Cosmetic Crate";      Price = 49;  Desc = "One random cosmetic (odds shown in game)" },
	@{ Id = "dp_crate10";       Kind = "product"; Name = "Cosmetic Crate x10";  Price = 399; Desc = "Ten cosmetic crates" },
	@{ Id = "dp_growth";        Kind = "product"; Name = "Growth Boost";        Price = 49;  Desc = "Crops grow 1.5x faster for 30 minutes" },
	@{ Id = "dp_coin_s";        Kind = "product"; Name = "Small Coin Pack";     Price = 49;  Desc = "Coins worth about 12 minutes of play" },
	@{ Id = "dp_coin_m";        Kind = "product"; Name = "Medium Coin Pack";    Price = 99;  Desc = "Coins worth about 30 minutes of play" },
	@{ Id = "dp_coin_l";        Kind = "product"; Name = "Large Coin Pack";     Price = 149; Desc = "Coins worth about 1 hour of play" },
	@{ Id = "dp_tierskip";      Kind = "product"; Name = "Season Tier Skip";    Price = 49;  Desc = "Skip one tier of the Moon Season" },
	@{ Id = "dp_starter";       Kind = "product"; Name = "Starter Pack";        Price = 99;  Desc = "One time only: 1 hour of coins, 3 cosmetic crates, a Growth Boost, a Rename Token and the Early Bird title" },
	@{ Id = "dp_support";       Kind = "product"; Name = "Support the Developer"; Price = 49; Desc = "Supporter title. Thank you for helping Moonlit Grove grow!" }
)

# Results from earlier runs (so nothing is created twice)
$results = [ordered]@{}
if (Test-Path $resultsFile) {
	$saved = Get-Content $resultsFile -Raw | ConvertFrom-Json
	foreach ($p in $saved.PSObject.Properties) { $results[$p.Name] = [string]$p.Value }
}

$created = 0; $failed = 0
foreach ($it in $items) {
	if ($results.Contains($it.Id)) {
		Write-Host ("skip   {0,-20} already created ({1})" -f $it.Name, $results[$it.Id]) -ForegroundColor DarkGray
		continue
	}
	if ($it.Kind -eq "pass") {
		$url = "https://apis.roblox.com/game-passes/v1/universes/$UniverseId/game-passes"
		$idField = "gamePassId"
	} else {
		$url = "https://apis.roblox.com/developer-products/v2/universes/$UniverseId/developer-products"
		$idField = "productId"
	}
	$out = & curl.exe -s -w "`n%{http_code}" -X POST $url `
		-H "x-api-key: $key" `
		-F "name=$($it.Name)" `
		-F "description=$($it.Desc)" `
		-F "price=$($it.Price)" `
		-F "isForSale=true"
	$lines = @($out -split "`n")
	$code = $lines[-1].Trim()
	$body = ($lines[0..([Math]::Max(0, $lines.Count - 2))] -join "`n")
	if ($code -ne "200") {
		Write-Host ("FAILED {0,-20} HTTP {1}: {2}" -f $it.Name, $code, $body) -ForegroundColor Red
		$failed++
		if ($code -eq "401" -or $code -eq "403") {
			Write-Host "The key was refused. Check it has game-pass:write and developer-product:write for this experience, and the right Universe ID." -ForegroundColor Yellow
			break
		}
		continue
	}
	$json = $body | ConvertFrom-Json
	$newId = [string]$json.$idField
	if (-not $newId) {
		Write-Host ("FAILED {0,-20} no {1} in the reply: {2}" -f $it.Name, $idField, $body) -ForegroundColor Red
		$failed++
		continue
	}
	$results[$it.Id] = $newId
	($results | ConvertTo-Json) | Set-Content $resultsFile -Encoding ascii
	Write-Host ("ok     {0,-20} {1} R$  ->  ID {2}" -f $it.Name, $it.Price, $newId) -ForegroundColor Green
	$created++
	Start-Sleep -Milliseconds 600 # stay well under the API rate limit
}

# Write the IDs into src/config/Products.luau (AssetId = 0 -> AssetId = <ID>)
$text = [IO.File]::ReadAllText($productsFile)
$updated = 0
foreach ($id in $results.Keys) {
	$pattern = '(\{ Id = "' + [regex]::Escape($id) + '",[^\r\n]*?AssetId = )\d+'
	$new = [regex]::Replace($text, $pattern, ('${1}' + $results[$id]))
	if ($new -ne $text) { $updated++ }
	$text = $new
}
[IO.File]::WriteAllText($productsFile, $text, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "Created $created, failed $failed, IDs written into Products.luau: $updated" -ForegroundColor Cyan
Write-Host "Next: run build-place.bat, open MonsterGarden.rbxlx, publish again." -ForegroundColor Cyan
Write-Host "Then delete the API key on create.roblox.com and delete .roblox-api-key.txt." -ForegroundColor Yellow
