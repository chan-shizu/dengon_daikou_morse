.PHONY: ios android gen build-ios build-android clean

ios:
	flutter run -d iphone

ipad-device:
	flutter run -d 00156254L000166

android:
	flutter run -d android

gen:
	flutter pub run build_runner build --delete-conflicting-outputs

watch:
	flutter pub run build_runner watch --delete-conflicting-outputs

build-ios:
	flutter build ipa

build-android:
	flutter build apk

clean:
	flutter clean && flutter pub get
