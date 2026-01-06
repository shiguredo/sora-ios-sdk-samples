.PHONY: fmt fmt-lint build

# デフォルトのパスを "." に設定
TARGET_PATH ?= .

# すべてを実行
all: fmt fmt-lint

# swift-format
fmt:
	swift format --in-place --recursive $(TARGET_PATH)

# swift-format lint
fmt-lint:
	swift format lint --strict --parallel --recursive $(TARGET_PATH)

# SamplesApp build
build:
	cd SamplesApp && xcodebuild \
		-project 'SamplesApp.xcodeproj' \
		-scheme 'SamplesApp' \
		-sdk iphoneos26.1 \
		-arch arm64 \
		-configuration Release \
		-derivedDataPath build \
		-skipPackagePluginValidation \
		clean build \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY= \
		PROVISIONING_PROFILE= \
		ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS=NO
