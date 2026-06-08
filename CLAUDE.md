# LatteMio — Reglas del proyecto

## Plataforma
- Target: macOS 14.0 (Sonoma) o superior
- Arquitectura: arm64 (MacBook Pro M3 Max)
- Xcode con Swift 5.9+

## Arquitectura de la app
- Menu bar pura: `LSUIElement = true` en Info.plist, sin ícono en el Dock
- Usar `MenuBarExtra` (SwiftUI Scene) con `.menuBarExtraStyle(.window)` para el popover
- Sin ventana principal ni `WindowGroup`

## Seguridad y firma
- **Sin App Sandbox** — necesario para ejecutar `yt-dlp` y binarios externos via `Process`
- Sin entitlements de sandbox (`com.apple.security.app-sandbox` ausente)
- Firma ad-hoc: `CODE_SIGN_IDENTITY = "-"`, sin equipo de desarrollo
- Sin notarización (uso personal, no se distribuye)

## Estructura del proyecto
- **XcodeGen** genera el `.xcodeproj` a partir de `project.yml`
- El `.xcodeproj` generado NO se versiona (agregarlo a `.gitignore`)
- Todo el código fuente en `Sources/`
- `Info.plist` generado por XcodeGen en la raíz del proyecto

## Dependencias externas
- `yt-dlp`: binario externo, llamado via `Foundation.Process`
- `ffmpeg` (opcional, para merge de streams)

## Convenciones
- SwiftUI lifecycle (`@main`, `App` protocol)
- Evitar AppKit directamente salvo donde SwiftUI no alcance
- No usar App Sandbox bajo ninguna circunstancia
