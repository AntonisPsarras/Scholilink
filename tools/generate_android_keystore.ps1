# Creates android/upload-keystore.jks and android/key.properties for release APK signing.
# Back up the keystore — you need the same file for every future update or Android will
# refuse to install over an existing app.
param(
  [string]$KeystorePath = (Join-Path $PSScriptRoot "..\android\upload-keystore.jks"),
  [string]$KeyPropertiesPath = (Join-Path $PSScriptRoot "..\android\key.properties")
)

if (Test-Path $KeystorePath) {
  Write-Error "Keystore already exists at $KeystorePath. Delete it first if you intend to regenerate."
  exit 1
}

$password = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
Write-Host "Generating release keystore..."

keytool -genkeypair -v `
  -keystore $KeystorePath `
  -storetype PKCS12 `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload `
  -storepass $password -keypass $password `
  -dname "CN=ScholiLink, OU=Mobile, O=ScholiLink, L=Athens, ST=Attica, C=GR"

@"
storePassword=$password
keyPassword=$password
keyAlias=upload
storeFile=upload-keystore.jks
"@ | Set-Content -Path $KeyPropertiesPath -Encoding UTF8

Write-Host "Created:"
Write-Host "  $KeystorePath"
Write-Host "  $KeyPropertiesPath"
Write-Host ""
Write-Host "Register SHA-1 in Firebase (Project settings -> ScholiLink Android app):"
keytool -list -v -keystore $KeystorePath -alias upload -storepass $password | Select-String "SHA1:"
