# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS Human Interface Guidelines

## Stack

SwiftUI, CoreWLAN, and CoreLocation; a native Xcode app project is selected from the two permitted project layouts so the app bundle can carry its required location permission metadata.

## Users

Mac users inspecting nearby Wi-Fi networks to understand channel congestion and make practical channel choices for their own network.

## Product Purpose

AetherScan scans nearby Wi-Fi networks, identifies the Mac's current connection, explains channel conflicts, and recommends less congested channels for the local environment.

## Positioning

A lightweight, on-device spectral Wi-Fi inspector that combines a nearby-network scan with a diagnosis of same-channel and adjacent-channel interference.

## Operating Context

The app runs on macOS 13 or later. It automatically begins its first scan on launch, requests location access when needed to reveal SSIDs, and provides manual refresh and network-band filters. The interface is available in Portuguese and English.

## Capabilities and Constraints

- Use SwiftUI with CoreWLAN and CoreLocation; target macOS 13+.
- Show available SSID, BSSID, band/frequency, channel, channel width, and signal strength, plus the current connection when the system exposes them.
- Diagnose same-channel contention and adjacent-channel overlap on 2.4 GHz; recommend channels based on the networks visible in the latest scan.
- Availability and completeness of scan fields depend on macOS permissions, hardware, regulatory region, and what CoreWLAN exposes. Explain missing access or scan data without presenting estimates as measured facts.
- Provide `NSLocationWhenInUseUsageDescription` in the app's Info.plist. No cloud service or remote scanning is part of the product brief.
- The physical app display name is AetherScan; the interface is localized in Portuguese and English, following the system language.

## Brand Commitments

Product name: AetherScan. Descriptor: “The Spectral Wi-Fi Inspector for macOS.” The requested interface follows native macOS Human Interface Guidelines, supports Dark Mode and native translucency, and uses the `wifi.badge.plus` symbol where available.

## Evidence on Hand

No existing app, scan captures, or external product evidence is present in the repository. Any illustrative network rows must be clearly marked as sample data, never represented as a live scan.

## Product Principles

- Keep scanning local and focused on the user's immediate Wi-Fi environment.
- Make measured scan results distinct from unavailable or inferred information.
- Explain channel health in actionable, understandable terms.
- Keep the current network and the next useful action easy to find.
- Make permission and scan failures recoverable.
