#!/usr/bin/env bash
set -e
flutter doctor
flutter pub get
cd ios && pod install && cd ..
flutter analyze
