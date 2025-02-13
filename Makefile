SHELL := /bin/bash

.PHONY: help setup setup-asdf setup-deps setup-mac setup-linux test

help: ## Show this help
	@echo "Lux Development Setup Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

setup: ## Run complete setup (recommended)
	@echo "Starting Lux setup..."
	@if [ ! -x "$$(command -v asdf)" ]; then \
		echo "asdf not found. Please install asdf first:"; \
		echo "  Mac: brew install asdf"; \
		echo "  Linux: git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1"; \
		echo "  Then add it to your shell config and restart your terminal"; \
		exit 1; \
	fi
	@$(MAKE) setup-asdf
	@$(MAKE) setup-deps
	@echo "Setup complete! Run 'make test' to verify installation"

setup-asdf: ## Install asdf plugins and tools
	@echo "Installing asdf plugins..."
	@asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git || true
	@asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git || true
	@asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git || true
	@asdf plugin add python https://github.com/danhper/asdf-python.git || true
	@asdf plugin add poetry https://github.com/asdf-community/asdf-poetry.git || true
	@echo "Installing tools with asdf..."
	@asdf install

setup-mac: ## Install Mac-specific dependencies
	@echo "Installing Mac dependencies..."
	@xcode-select --install || true
	@if [ ! -x "$$(command -v brew)" ]; then \
		echo "Homebrew not found. Please install it first:"; \
		echo "/bin/bash -c \"$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""; \
		exit 1; \
	fi
	@brew install autoconf automake libtool wxmac fop openssl@3
	@echo "export KERL_CONFIGURE_OPTIONS=\"--with-ssl=$$(brew --prefix openssl@3)\"" >> ~/.zshrc
	@echo "export KERL_CONFIGURE_OPTIONS=\"--with-ssl=$$(brew --prefix openssl@3)\"" >> ~/.bashrc
	@export KERL_CONFIGURE_OPTIONS="--with-ssl=$$(brew --prefix openssl@3)"

setup-linux: ## Install Linux-specific dependencies
	@echo "Installing Linux dependencies..."
	@if [ -f /etc/debian_version ]; then \
		sudo apt-get update && \
		sudo apt-get install -y build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk; \
	elif [ -f /etc/redhat-release ]; then \
		sudo yum groupinstall -y "Development Tools" && \
		sudo yum install -y autoconf ncurses-devel openssl-devel wxGTK3-devel wxGTK-webview3-devel mesa-libGL-devel mesa-libGLU-devel libpng-devel libssh-devel unixODBC-devel xsltproc fop libxml2-utils ncurses-devel java-11-openjdk-devel; \
	else \
		echo "Unsupported Linux distribution"; \
		exit 1; \
	fi

setup-deps: ## Install project dependencies
	@echo "Installing project dependencies..."
	@mix local.hex --force
	@mix local.rebar --force
	@mix setup 

test: ## Run test suite
	@echo "Running test suite..."
	@mix test.unit
	@mix python.test 
	@mix test.integration