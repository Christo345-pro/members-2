# members

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Runtime Config (`--dart-define`)

The app reads config values from compile-time environment variables:

- `ADMIN_API_BASE_URL` (default: `https://devtest.weather-hooligan.co.za`)
- `MEMBERS_WHATSAPP_DEFAULT_COUNTRY_CODE` (default: `27`)
- `MEMBERS_WHATSAPP_MESSAGE_TEMPLATE` (default: `Hello {name}, this is Weather Hooligan support.`)
- `MEMBERS_WHATSAPP_MESSAGE_DEFAULT` (default: `Hello from Weather Hooligan support.`)
- `MEMBERS_WHATSAPP_SCHEME_BASE` (default: `whatsapp://send`)
- `MEMBERS_WHATSAPP_WEB_BASE` (default: `https://wa.me`)

Example:

```bash
flutter run \
  --dart-define=ADMIN_API_BASE_URL=https://devtest.weather-hooligan.co.za \
  --dart-define=MEMBERS_WHATSAPP_DEFAULT_COUNTRY_CODE=27 \
  --dart-define=MEMBERS_WHATSAPP_MESSAGE_TEMPLATE="Hi {name}, Weather Hooligan here." \
  --dart-define=MEMBERS_WHATSAPP_MESSAGE_DEFAULT="Hi from Weather Hooligan."
```

## Web Viewer (Linux/VPS)

If VS Code only shows `Linux (desktop)`, run the app as a web server:

```bash
./run_web_vps.sh 0.0.0.0 8082
```

Then open:

```text
http://<server-ip>:8082
```

You can also launch from VS Code with:

- `Members Admin (Web Server 8082)` in `.vscode/launch.json`
