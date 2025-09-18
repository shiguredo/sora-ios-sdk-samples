.PHONY: fmt fmt-lint

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
