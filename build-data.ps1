# Turns a GeoJSON-sequence export of Croatian venues into small static files the app loads instantly:
#   data/index.json              - grid cells that have places, plus build date
#   data/cells/<lat>_<lng>.json  - places in one 0.1° x 0.1° cell (~11 x 8 km), key = floor(coord * 10)
# Input is produced by the GitHub Action (.github/workflows/refresh-data.yml) from Geofabrik's Croatia
# extract with osmium; see that file for the exact commands.
param(
  [Parameter(Mandatory)][string]$GeoJsonSeq,
  [string]$Out = (Join-Path $PSScriptRoot 'data')
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture

# Only the tags the app actually shows; everything else is dropped to keep files small.
$keep = @('name', 'amenity', 'shop', 'tourism', 'cuisine', 'opening_hours',
  'addr:street', 'addr:housenumber', 'addr:city', 'website', 'contact:website', 'phone', 'contact:phone',
  'website:menu', 'contact:menu', 'menu:url', 'outdoor_seating', 'diet:vegan', 'diet:vegetarian',
  'internet_access', 'takeaway')
$amenities = 'restaurant', 'cafe', 'bar', 'pub', 'biergarten', 'nightclub', 'fast_food', 'ice_cream'
$shops = 'bakery', 'pastry', 'confectionery'
$tourism = 'hotel', 'hostel', 'guest_house', 'apartment', 'motel'

# Centre of a geometry's bounding box: good enough for a map pin on a building or plot.
function Get-Center($geometry) {
  if ($geometry.type -eq 'Point') { return $geometry.coordinates }
  $minX = 999; $minY = 999; $maxX = -999; $maxY = -999
  $stack = New-Object System.Collections.Stack
  $stack.Push($geometry.coordinates)
  while ($stack.Count) {
    $c = $stack.Pop()
    if ($c.Count -ge 2 -and $c[0] -isnot [array] -and $c[0] -isnot [Collections.IList]) {
      $x = [double]$c[0]; $y = [double]$c[1]
      if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
    } else {
      foreach ($child in $c) { $stack.Push($child) }
    }
  }
  return @((($minX + $maxX) / 2), (($minY + $maxY) / 2))
}

$cells = @{}
$seen = New-Object System.Collections.Generic.HashSet[string]
$count = 0
foreach ($line in [IO.File]::ReadLines((Resolve-Path $GeoJsonSeq), [Text.Encoding]::UTF8)) {
  $line = $line.Trim([char]0x1e, ' ', "`r") # osmium prefixes each record with an RS character
  if (-not $line) { continue }
  $f = $line | ConvertFrom-Json
  $p = $f.properties
  if (-not $p.name) { continue }
  if (-not (($p.amenity -in $amenities) -or ($p.shop -in $shops) -or ($p.tourism -in $tourism))) { continue }
  $id = "$($p.'@type')/$($p.'@id')"
  if (-not $seen.Add($id)) { continue }

  $lon, $lat = Get-Center $f.geometry
  $tags = [ordered]@{}
  foreach ($k in $keep) { if ($p.$k) { $tags[$k] = [string]$p.$k } }
  $key = '{0}_{1}' -f [math]::Floor($lat * 10), [math]::Floor($lon * 10)
  if (-not $cells.ContainsKey($key)) { $cells[$key] = New-Object System.Collections.Generic.List[object] }
  $cells[$key].Add(@($id, [math]::Round($lat, 5), [math]::Round($lon, 5), $tags))
  $count++
}
if ($count -lt 5000) { throw "Only $count places found - input looks wrong, not writing data." }

# Write files (UTF-8 without BOM). Old cells are removed so deleted places disappear.
$cellDir = Join-Path $Out 'cells'
if (Test-Path $cellDir) { Remove-Item $cellDir -Recurse -Force }
New-Item -ItemType Directory -Force $cellDir | Out-Null
$utf8 = New-Object Text.UTF8Encoding $false
foreach ($key in $cells.Keys) {
  $json = ConvertTo-Json -InputObject $cells[$key].ToArray() -Depth 4 -Compress
  [IO.File]::WriteAllText((Join-Path $cellDir "$key.json"), $json, $utf8)
}
$index = [ordered]@{
  generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd', $inv)
  cellSize  = 0.1
  places    = $count
  cells     = @($cells.Keys | Sort-Object)
}
[IO.File]::WriteAllText((Join-Path $Out 'index.json'), (ConvertTo-Json -InputObject $index -Compress), $utf8)
Write-Host "Wrote $count places into $($cells.Count) cells."
