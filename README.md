# LocalApi (Platform-Independent .NET Web API)

Language: English | [Turkce](./README.tr.md)

A single-codebase .NET Web API that runs on Windows, Linux, and macOS with one-click installers.

## Features

- Single API codebase for all platforms
- Runtime DB provider selection: `SqlServer`, `PostgreSql`, `Sqlite`
- `--migrate` mode for migration + seed, then exit
- Platform-specific install/uninstall scripts
- Service integration:
  - Windows Service
  - Linux systemd
  - macOS launchd
- Bootstrap scripts for clone/pull + install

## Project Structure

- `src/LocalApi`
- `installer/windows`
- `installer/linux`
- `installer/macos`
- `scripts`
- `bootstrap`

## API Endpoints

- `GET /api/products`
- `GET /api/products/{id:int}`

Product model:

- `Id`
- `Name`
- `Price`

## Database Provider

Set in `appsettings.json` or `appsettings.Production.json`:

- `DatabaseProvider`: `SqlServer | PostgreSql | Sqlite`
- `ConnectionStrings.SqlServer`
- `ConnectionStrings.PostgreSql`
- `ConnectionStrings.Sqlite`

## Migrate + Seed

```bash
./LocalApi --migrate
```

Seed data:

- Kalem - 15
- Defter - 45
- Kitap - 120

## One-Command Bootstrap Install

### Linux/macOS

```bash
./bootstrap/install.sh
```

Optional override:

```bash
./bootstrap/install.sh https://github.com/BizimGri/oneclick-localapi-installer.git ./bootstrap/oneclick-localapi-installer
```

### Windows

```bat
bootstrap\install.cmd
```

Alternative:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap\install.ps1
```

Bootstrap behavior:

- Installs `git` automatically when possible
- Clones repo if missing
- Pulls repo if already cloned (`--ff-only`)
- Runs platform one-click installer
- Removes temporary bootstrap clone folder (default target only)

## Platform Installers

### Windows

```bat
installer\windows\oneclick-install.cmd
```

### Linux

```bash
./installer/linux/oneclick-install.sh
```

Note: Linux install requires root permissions (`sudo`).

### macOS

```bash
./installer/macos/oneclick-install.sh
```

Note: You can start without `sudo`; script requests elevation only when needed.

## Uninstall

### Windows

```bat
installer\windows\oneclick-uninstall.cmd
```

### Linux

```bash
./installer/linux/oneclick-uninstall.sh
```

### macOS

```bash
./installer/macos/oneclick-uninstall.sh
```

## Tested Environments

- Windows ARM64
- Linux (Ubuntu Server)
- macOS

## Security Notes

For production:

- Restrict network access with firewall/IP rules
- Use TLS behind reverse proxy
- Add JWT/OIDC authn/authz
- Keep secrets in env vars or secret manager

## Quick Validation Checklist

1. `dotnet build src/LocalApi/LocalApi.csproj`
2. Service is running after install
3. `GET /api/products` returns 3 seeded rows
4. Service auto-starts after reboot
5. DB provider connectivity verified
