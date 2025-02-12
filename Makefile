.PHONY: fmt fmt-lint

# すべてを実行
all: fmt fmt-lint

# swift-format
fmt:
	swift format --in-place --recursive .

# swift-format lint
fmt-lint:
	swift format lint --strict --parallel --recursive .

