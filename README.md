# Hyouka: Neon Frontier

A real Godot 4.7.2 .NET 3D Android prototype.

Features:
- Procedural randomized 3D arena
- Third-person player controller
- Enemy AI and escalating waves
- Projectile combat
- Health and pickup system
- Dynamic lights, emissive materials and shadows
- Android touch controls
- Main menu, pause and game-over flow

Distribution target: Android debug APK.

There is no HTML game implementation in this repository.
The GitHub Actions workflow downloads the official Godot 4.7.2 .NET editor and Android export templates, validates the project, exports the APK, scans the Godot logs, and uploads the APK as an artifact.
