#!/bin/bash

# Create necessary directories if they don't exist
mkdir -p core/lib/lux core/test core/config core/priv
mkdir -p web/lib/lux_web web/assets web/test
mkdir -p cli/lib/lux_cli cli/bin
mkdir -p docs/guides docs/api docs/architecture
mkdir -p examples

# Move core code
echo "Moving core code..."
cp -r lib/lux/* core/lib/lux/
cp lib/lux.ex core/lib/lux.ex
cp lib/types.ex core/lib/types.ex

# Move test code
echo "Moving test code..."
cp -r test/lux core/test/
cp -r test/unit core/test/
cp -r test/integration core/test/
cp test/test_helper.exs core/test/

# Move configuration
echo "Moving configuration..."
cp -r config/* core/config/

# Move priv directory
echo "Moving priv directory..."
cp -r priv/* core/priv/

# Create basic web structure
echo "Creating web structure..."
mkdir -p web/lib/lux_web/controllers
mkdir -p web/lib/lux_web/live
mkdir -p web/lib/lux_web/components
mkdir -p web/lib/lux_web/templates
mkdir -p web/lib/lux_web/views
mkdir -p web/assets/js
mkdir -p web/assets/css
mkdir -p web/assets/js/nodes

# Create basic CLI structure
echo "Creating CLI structure..."
mkdir -p cli/lib/lux_cli/commands
mkdir -p cli/lib/lux_cli/templates

# Move documentation
echo "Moving documentation..."
cp -r guides/* docs/guides/
cp README.md docs/
cp CHANGELOG.md docs/

# Create example directories
echo "Creating example directories..."
mkdir -p examples/simple_agent
mkdir -p examples/trading_system
mkdir -p examples/content_creation

# Copy new files to their final locations
echo "Copying new files to their final locations..."
cp README.md.new README.md
cp mix.exs.new mix.exs
cp Makefile.new Makefile

# Create formatter files for each component
echo "Creating formatter files..."
cp .formatter.exs core/
cp .formatter.exs web/
cp .formatter.exs cli/

# Create gitignore files for each component
echo "Creating gitignore files..."
cat > core/.gitignore << EOF
# The directory Mix will write compiled artifacts to.
/_build/

# If you run "mix test --cover", coverage assets end up here.
/cover/

# The directory Mix downloads your dependencies sources to.
/deps/

# Where third-party dependencies like ExDoc output generated docs.
/doc/

# Ignore .fetch files in case you like to edit your project deps locally.
/.fetch

# If the VM crashes, it generates a dump, let's ignore it too.
erl_crash.dump

# Also ignore archive artifacts (built via "mix archive.build").
*.ez

# Ignore package tarball (built via "mix hex.build").
lux_core-*.tar

# Temporary files, for example, from tests.
/tmp/
EOF

cp core/.gitignore web/
cp core/.gitignore cli/

echo "Refactoring complete!" 