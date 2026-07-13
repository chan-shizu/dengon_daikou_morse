.PHONY: ios ios-sim android gen build-ios build-android clean

ios:
	flutter run -d iphone

ios-sim:
	flutter run -d "iPhone SE"

ipad-device:
	flutter run -d 00008030-001A40301E88C02E

iPhone-se-device:
	flutter run -d 00008110-000C64CC2268401E

android:
	flutter run -d android

android-device:
	flutter run -d 00156254L000166

gen:
	dart run build_runner build

watch:
	dart run build_runner watch

build-ios:
	flutter build ipa

build-android:
	flutter build apk

clean:
	flutter clean && flutter pub get
