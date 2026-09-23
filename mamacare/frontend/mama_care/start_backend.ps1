$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot 'backend')
dart pub get
dart run bin/server.dart
