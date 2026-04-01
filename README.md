# Sleep & Code

iOS app that correlates GitHub commit activity with Oura ring sleep quality. Understand how your sleep affects your coding output.

## Features

- **Correlation Dashboard** — Dual-axis charts (sleep score + commits), scatter plots, bracket analysis by sleep quality
- **Smart Insights** — On-device statistical analysis: Pearson correlation, optimal sleep range, deep sleep impact, day-of-week patterns
- **Gentle Nudges** — Morning/evening/weekly notifications based on your sleep data

## Architecture

Fully on-device. No backend server. Zero third-party dependencies.

- **SwiftUI** + **SwiftData** + **Swift Charts**
- **AuthenticationServices** for Oura OAuth
- **BackgroundTasks** for periodic sync
- **UserNotifications** for local alerts
- **Security** framework for Keychain token storage

## Setup

1. Open `SleepAndCode/` in Xcode (generate project with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `cd SleepAndCode && xcodegen`)
2. Set your Oura app credentials in `Utilities/Constants.swift`
3. Build and run on iOS 17+ simulator or device
4. Paste a GitHub fine-grained PAT (read-only repo access)
5. Connect Oura via OAuth
6. Data syncs automatically every ~4 hours via Background App Refresh

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 6.0
