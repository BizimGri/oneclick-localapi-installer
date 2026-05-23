# LocalApi (Platform-Independent .NET Web API)

Bu repository, tek API kod tabanını Windows/Linux/macOS üzerinde çalıştırmak için hazırlanmıştır.

## Özellikler

- .NET Web API (tek kod tabanı)
- Runtime DB provider seçimi: `SqlServer`, `PostgreSql`, `Sqlite`
- `--migrate` ile tek komutta migration + seed
- Platform bazlı installer/uninstaller scriptleri
- Windows Service / systemd / launchd servis entegrasyonu
- Mümkün olan en otomatik önkoşul kurulum akışı

## Proje Yapısı

- `src/LocalApi`: API kodu
- `installer/windows`: Windows kurulum ve kaldırma
- `installer/linux`: Linux kurulum ve kaldırma
- `installer/macos`: macOS kurulum ve kaldırma
- `scripts`: publish scriptleri

## API Endpointleri

- `GET /api/products`
- `GET /api/products/{id:int}`

Product alanları:

- `Id`
- `Name`
- `Price`

## DB Provider Seçimi

`appsettings.json` veya `appsettings.Production.json` içinde:

- `DatabaseProvider`: `SqlServer | PostgreSql | Sqlite`
- `ConnectionStrings.SqlServer`
- `ConnectionStrings.PostgreSql`
- `ConnectionStrings.Sqlite`

## Migrate + Seed

```bash
./LocalApi --migrate
```

Seed:

- Kalem - 15
- Defter - 45
- Kitap - 120

## Publish

### Linux/macOS

```bash
./scripts/publish.sh
```

`publish.sh` dotnet SDK yoksa otomatik kurmayı dener (Linux'ta gerekirse sudo ile kendini yeniden calistirir, macOS'ta Homebrew kullanir).

### Windows

```powershell
./scripts/publish.ps1
```

`publish.ps1` dotnet SDK yoksa otomatik kurmayı dener (`winget`/`choco`).

Varsayilan davranis: sadece mevcut makinenin runtime'i publish edilir.

Ornekler:

- Windows x64 -> `publish/win-x64`
- Windows ARM64 -> `publish/win-arm64`
- Linux x64 -> `publish/linux-x64`
- Linux ARM64 -> `publish/linux-arm64`
- macOS Intel -> `publish/osx-x64`
- macOS Apple Silicon -> `publish/osx-arm64`

## Otomatik Kurulum Davranışı

Installer scriptleri şu adımları otomatik dener:

- Publish dosyalarını kopyalar
- Production config üretir
- `--migrate` çalıştırır
- Servisi kurar/günceller/başlatır
- Runtime yoksa platforma göre paket yöneticisi ile kurmayı dener
- İsteğe bağlı DB server kurulumunu dener

Notlar:

- Self-contained publish kullanıldığında runtime kurulumu atlanır
- SQL Server otomatik kurulum Linux/macOS için dağıtıma bağlıdır; gerektiğinde Docker önerilir

## Windows Kurulum

Tek seferde tum surec (onerilen):

```bat
installer\windows\oneclick-install.cmd
```

Bu komut otomatik olarak:

- Gerekirse UAC ile admin olarak yeniden baslar
- Execution Policy bypass ile publish scriptini calistirir
- Publish adiminda runtime'i Windows mimarisine gore otomatik secer (`win-x64`/`win-arm64`)
- Execution Policy bypass ile install scriptini calistirir

Opsiyonel parametreler:

```bat
installer\windows\oneclick-install.cmd -DatabaseProvider PostgreSql -InstallDbServer
installer\windows\oneclick-install.cmd -SkipPublish -SourcePath C:\path\to\publish\win-x64
```

Alternatif manuel kurulum:

```powershell
./installer/windows/install.ps1 -SourcePath "./publish/win-x64" -InstallPath "C:\LocalApi" -Port "5099" -DatabaseProvider "Sqlite"
```

Opsiyonel DB server kurulumu:

```powershell
./installer/windows/install.ps1 -SourcePath "./publish/win-x64" -DatabaseProvider "PostgreSql" -InstallDbServer
```

Yaptıkları:

- Admin kontrolü
- Runtime kontrol/kurulum (winget/choco)
- Opsiyonel DB server kurulum denemesi
- Service create/update/start
- Firewall inbound rule
- Idempotent kurulum

### Windows Kaldırma

Tek seferde kaldirma (onerilen):

```bat
installer\windows\oneclick-uninstall.cmd
```

Alternatif manuel:

```powershell
./installer/windows/uninstall.ps1 -InstallPath "C:\LocalApi" -Port "5099"
```

## Linux Kurulum

Tek seferde tum surec (onerilen):

```bash
./installer/linux/oneclick-install.sh
```

Opsiyonel parametreler:

```bash
./installer/linux/oneclick-install.sh --db-provider PostgreSql --install-db-server
./installer/linux/oneclick-install.sh --skip-publish --source /path/to/publish/linux-x64
```

Alternatif manuel:

```bash
sudo ./installer/linux/install.sh ./publish/linux-x64
```

Opsiyonel DB server kurulumu:

```bash
sudo LOCALAPI_DB_PROVIDER=PostgreSql LOCALAPI_INSTALL_DB_SERVER=true ./installer/linux/install.sh ./publish/linux-x64
```

Yaptıkları:

- Runtime kontrol/kurulum (apt/dnf/yum/zypper)
- Opsiyonel DB server kurulum denemesi
- systemd service yaz/enable/restart
- Idempotent kurulum

### Linux Kaldırma

Tek seferde kaldirma (onerilen):

```bash
./installer/linux/oneclick-uninstall.sh
```

Alternatif manuel:

```bash
sudo ./installer/linux/uninstall.sh
```

## macOS Kurulum

Tek seferde tum surec (onerilen):

```bash
./installer/macos/oneclick-install.sh
```

Opsiyonel parametreler:

```bash
./installer/macos/oneclick-install.sh --db-provider PostgreSql --install-db-server
./installer/macos/oneclick-install.sh --skip-publish --source /path/to/publish/osx-arm64
```

Alternatif manuel:

```bash
sudo ./installer/macos/install.sh ./publish/osx-arm64
```

Opsiyonel DB server kurulumu:

```bash
sudo LOCALAPI_DB_PROVIDER=PostgreSql LOCALAPI_INSTALL_DB_SERVER=true ./installer/macos/install.sh ./publish/osx-arm64
```

Yaptıkları:

- Runtime kontrol/kurulum (Homebrew varsa)
- Opsiyonel DB server kurulum denemesi (Homebrew)
- launchd plist bootstrap/enable
- Idempotent kurulum

### macOS Kaldırma

Tek seferde kaldirma (onerilen):

```bash
./installer/macos/oneclick-uninstall.sh
```

Alternatif manuel:

```bash
sudo ./installer/macos/uninstall.sh
```

## Güvenlik Notu

Production ortamında en az:

- Firewall'da sadece gerekli IP/subnet erişimi verin
- TLS ve reverse proxy kullanın
- JWT/OIDC ile auth/authz ekleyin
- Connection stringleri secrets manager veya environment variable ile yönetin

## Kısa Doğrulama Checklist

1. `dotnet build src/LocalApi/LocalApi.csproj`
2. Installer çalıştıktan sonra servis ayakta mı?
3. `GET /api/products` 3 seed kaydı dönüyor mu?
4. Reboot sonrası servis auto-start ediyor mu?
5. Seçilen provider ile DB bağlantısı doğrulandı mı?
