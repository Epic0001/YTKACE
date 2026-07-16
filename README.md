# YTKACE

A free and open-source YouTube enhancer for iOS with downloads, SponsorBlock, player controls, and interface customization.

## Table of Contents

- [Screenshots](#screenshots)
- [Main Features](#main-features)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Build with GitHub Actions](#build-with-github-actions)
- [Build Locally](#build-locally)
- [FAQ](#faq)
- [License](#license)

## Screenshots

Screenshots coming soon.

## Main Features

- Download videos, audio, and Shorts with quality and audio-track selection
- Built-in download manager with thumbnails, multiple layouts, sorting, queue, and mini-player
- Custom video and audio players for downloaded media
- Built-in SponsorBlock with markers, automatic skipping, and Ask mode
- Background playback, Picture in Picture, loop, playback speed, and custom gestures
- OLED mode, Premium logo, and player interface customization
- Hide, rename, and reorder tabs with a custom startup tab
- Hide comments, overlays, navigation items, Shorts elements, and other YouTube UI
- Wi-Fi and cellular quality preferences
- Cast compatibility and sideload fixes
- Copy comments and video information
- No activation, telemetry, or update checks

**YTKACE preferences can be found by opening the YTKACE tab and tapping the gear icon.**

See the full [feature matrix](docs/FEATURE_MATRIX.md).

## Compatibility

- **iOS:** 16.0 and newer
- **Architecture:** arm64
- **Latest confirmed YouTube:** 21.28.3
- **YTKACE:** 0.6.2

The same injected IPA can be installed with TrollStore, an AppSync-compatible installer, or a developer-certificate sideloader.

YTKACE does not require CydiaSubstrate, MobileSubstrate, Cephei, libhooker, or ElleKit.

## Installation

Download the latest build from [Releases](https://github.com/Epic0001/YTKACE/releases/latest), then install it with your preferred IPA installer.

> [!NOTE]
> YTKACE does not include YouTube. You are responsible for supplying and using a decrypted YouTube IPA that you are legally allowed to use.

## Build with GitHub Actions

1. Fork this repository.
2. Open the **Actions** tab in your fork.
3. Select **IPA** and press **Run workflow**.
4. Paste a direct download link to your decrypted YouTube IPA.
5. Start the workflow.
6. Download **YTKACE-IPA** from the finished run.

The URL must point directly to the IPA file, not a download page.

To build only the tweak package, run the **Deb** workflow. It produces the `.deb` as a workflow artifact.

## Build Locally

Install [Theos](https://theos.dev/docs/installation), then run:

```sh
make package FINALPACKAGE=1
```

The build produces `dist/YTKACE.dylib` and a package in `packages/`.

To inject the dylib into your own decrypted YouTube IPA:

```sh
bash Scripts/sideload-repack.sh YouTube.ipa dist/YTKACE.dylib YTKACE_YouTube.ipa
```

The repack script requires Python 3, `ldid`, `zip`, and `unzip`. It works on macOS and Linux, including WSL.

## FAQ

<details>
  <summary>Where are the settings?</summary>
  <p>Open the YTKACE tab and tap the gear icon.</p>
</details>

<details>
  <summary>Does it work without a jailbreak?</summary>
  <p>Yes. Inject the tweak into a decrypted YouTube IPA, then sign it with TrollStore or a sideloading service.</p>
</details>

<details>
  <summary>Does YTKACE use YTKPlus?</summary>
  <p>No. YTKACE is an independent clean-room implementation and does not load or ship YTKPlus.</p>
</details>

<details>
  <summary>Can a YouTube update break features?</summary>
  <p>Yes. YouTube uses private classes that can change between releases. The latest confirmed version is listed above.</p>
</details>

## License

YTKACE is available under the [MIT License](LICENSE).

Bundled FFmpeg libraries remain covered by their respective LGPL licenses.
