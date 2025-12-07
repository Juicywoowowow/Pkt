#!/bin/bash

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
RESET='\033[0m'

PKT_HOME="$HOME/.pkt"
PKT_BIN="$PKT_HOME/bin"
PKT_SRC="$PKT_HOME/src"
PKT_INSTALLED="$PKT_HOME/installed.json"

PACKAGE="$1"
MODE="$2"  # "update" if updating

# Package definitions - Termux-specific tools
declare -A REPOS
declare -A BUILDS
declare -A BINARIES
declare -A DEPS
declare -A PKG_DEPS

# termux-api - Termux API access
REPOS["termux-api"]="https://github.com/termux/termux-api.git"
BUILDS["termux-api"]="auto"
BINARIES["termux-api"]="termux-api"
DEPS["termux-api"]="make"
PKG_DEPS["termux-api"]="make"

# termux-styling - Terminal styling
REPOS["termux-styling"]="https://github.com/termux/termux-styling.git"
BUILDS["termux-styling"]="auto"
BINARIES["termux-styling"]="termux-styling"
DEPS["termux-styling"]="make"
PKG_DEPS["termux-styling"]="make"

# termux-boot - Run scripts on boot
REPOS["termux-boot"]="https://github.com/termux/termux-boot.git"
BUILDS["termux-boot"]="auto"
BINARIES["termux-boot"]="termux-boot"
DEPS["termux-boot"]="make"
PKG_DEPS["termux-boot"]="make"

# nnn - Terminal file manager (works great on Termux)
REPOS["nnn"]="https://github.com/jarun/nnn.git"
BUILDS["nnn"]="auto"
BINARIES["nnn"]="nnn"
DEPS["nnn"]="make"
PKG_DEPS["nnn"]="make libncurses readline"

# lazygit - Git TUI
REPOS["lazygit"]="https://github.com/jesseduffield/lazygit.git"
BUILDS["lazygit"]="go build -o lazygit && cp lazygit $PKT_BIN/"
BINARIES["lazygit"]="lazygit"
DEPS["lazygit"]="go"
PKG_DEPS["lazygit"]="golang"

# gotop - Terminal system monitor
REPOS["gotop"]="https://github.com/xxxserxxx/gotop.git"
BUILDS["gotop"]="go build -o gotop ./cmd/gotop && cp gotop $PKT_BIN/"
BINARIES["gotop"]="gotop"
DEPS["gotop"]="go"
PKG_DEPS["gotop"]="golang"

# lf - Terminal file manager
REPOS["lf"]="https://github.com/gokcehan/lf.git"
BUILDS["lf"]="go build -o lf && cp lf $PKT_BIN/"
BINARIES["lf"]="lf"
DEPS["lf"]="go"
PKG_DEPS["lf"]="golang"

# croc - File transfer tool
REPOS["croc"]="https://github.com/schollz/croc.git"
BUILDS["croc"]="go build -o croc && cp croc $PKT_BIN/"
BINARIES["croc"]="croc"
DEPS["croc"]="go"
PKG_DEPS["croc"]="golang"

# glow - Markdown renderer
REPOS["glow"]="https://github.com/charmbracelet/glow.git"
BUILDS["glow"]="go build -o glow && cp glow $PKT_BIN/"
BINARIES["glow"]="glow"
DEPS["glow"]="go"
PKG_DEPS["glow"]="golang"

# bat - Cat with syntax highlighting
REPOS["bat"]="https://github.com/sharkdp/bat.git"
BUILDS["bat"]="cargo build --release && cp target/release/bat $PKT_BIN/"
BINARIES["bat"]="bat"
DEPS["bat"]="cargo"
PKG_DEPS["bat"]="rust"

# Auto-detect build system and run
auto_build() {
    echo -e "${CYAN}Auto-detecting build system...${RESET}"
    
    # Check for Makefile first
    if [ -f "Makefile" ] || [ -f "makefile" ] || [ -f "GNUmakefile" ]; then
        echo -e "${GREEN}Found Makefile${RESET}"
        
        # Check if there's an install target
        if grep -q "^install:" Makefile 2>/dev/null || grep -q "^install:" makefile 2>/dev/null; then
            make && make PREFIX="$PKT_HOME" install
        else
            make
            # Try to find and copy the binary
            find_and_copy_binary
        fi
        return $?
    fi
    
    # Check for configure script
    if [ -f "configure" ]; then
        echo -e "${GREEN}Found configure script${RESET}"
        ./configure --prefix="$PKT_HOME" && make && make install
        return $?
    fi
    
    # Check for autogen.sh
    if [ -f "autogen.sh" ]; then
        echo -e "${GREEN}Found autogen.sh${RESET}"
        ./autogen.sh && ./configure --prefix="$PKT_HOME" && make && make install
        return $?
    fi
    
    # Check for CMakeLists.txt
    if [ -f "CMakeLists.txt" ]; then
        echo -e "${GREEN}Found CMakeLists.txt${RESET}"
        mkdir -p build && cd build
        cmake -DCMAKE_INSTALL_PREFIX="$PKT_HOME" .. && make && make install
        return $?
    fi
    
    # Check for setup.py (Python)
    if [ -f "setup.py" ]; then
        echo -e "${GREEN}Found setup.py${RESET}"
        pip install --user .
        return $?
    fi
    
    # Check for Cargo.toml (Rust)
    if [ -f "Cargo.toml" ]; then
        echo -e "${GREEN}Found Cargo.toml${RESET}"
        cargo build --release
        find_and_copy_binary "target/release"
        return $?
    fi
    
    # Check for go.mod (Go)
    if [ -f "go.mod" ]; then
        echo -e "${GREEN}Found go.mod${RESET}"
        go build -o "$PACKAGE"
        cp "$PACKAGE" "$PKT_BIN/"
        return $?
    fi
    
    # Check for Gradle (gradlew or build.gradle)
    if [ -f "gradlew" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
        echo -e "${GREEN}Found Gradle project${RESET}"
        
        # Install gradle/java if needed
        if ! command -v java &> /dev/null; then
            echo -e "${YELLOW}Installing Java...${RESET}"
            pkg install -y openjdk-17 2>/dev/null || apt install -y openjdk-17 2>/dev/null
        fi
        
        if [ -f "gradlew" ]; then
            # Use wrapper
            chmod +x gradlew
            ./gradlew build --no-daemon
        else
            # Install gradle if not present
            if ! command -v gradle &> /dev/null; then
                echo -e "${YELLOW}Installing Gradle...${RESET}"
                pkg install -y gradle 2>/dev/null || apt install -y gradle 2>/dev/null
            fi
            gradle build --no-daemon
        fi
        
        # Find and copy built jar or binary
        find_gradle_output
        return $?
    fi
    
    echo -e "${RED}No recognized build system found${RESET}"
    return 1
}

# Find Gradle build output and copy
find_gradle_output() {
    # Look for jar files in build/libs
    if [ -d "build/libs" ]; then
        local jar=$(find build/libs -name "*.jar" ! -name "*-sources.jar" ! -name "*-javadoc.jar" | head -1)
        if [ -n "$jar" ]; then
            cp "$jar" "$PKT_BIN/"
            
            # Create wrapper script to run the jar
            local jar_name=$(basename "$jar")
            cat > "$PKT_BIN/$PACKAGE" << EOF
#!/bin/bash
java -jar "\$HOME/.pkt/bin/$jar_name" "\$@"
EOF
            chmod +x "$PKT_BIN/$PACKAGE"
            echo -e "${GREEN}Installed $jar_name with wrapper script${RESET}"
            return 0
        fi
    fi
    
    # Look for native binary in build/native or build/bin
    for dir in "build/native" "build/bin" "build/exe"; do
        if [ -d "$dir" ]; then
            find_and_copy_binary "$dir"
            if [ $? -eq 0 ]; then
                return 0
            fi
        fi
    done
    
    echo -e "${YELLOW}No output binary/jar found, check build/libs manually${RESET}"
    return 1
}

# Find binary and copy to bin
find_and_copy_binary() {
    local search_dir="${1:-.}"
    
    # Look for binary with package name
    if [ -f "$search_dir/$PACKAGE" ]; then
        cp "$search_dir/$PACKAGE" "$PKT_BIN/"
        return 0
    fi
    
    # Look for any executable
    local binary=$(find "$search_dir" -maxdepth 2 -type f -executable ! -name "*.sh" ! -name "*.py" | head -1)
    if [ -n "$binary" ]; then
        cp "$binary" "$PKT_BIN/"
        return 0
    fi
    
    return 1
}

if [ -z "$PACKAGE" ]; then
    echo -e "${RED}Error: No package specified${RESET}"
    exit 1
fi

REPO="${REPOS[$PACKAGE]}"
BUILD="${BUILDS[$PACKAGE]}"
DEP_CMDS="${DEPS[$PACKAGE]}"
DEP_PKGS="${PKG_DEPS[$PACKAGE]}"

if [ -z "$REPO" ]; then
    echo -e "${RED}Error: Unknown package '$PACKAGE'${RESET}"
    exit 1
fi

# Install dependencies first
echo -e "${CYAN}Checking dependencies for $PACKAGE...${RESET}"

MISSING_DEPS=()
for cmd in $DEP_CMDS; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Missing: ${MISSING_DEPS[*]}${RESET}"
    echo -e "${CYAN}Installing build dependencies...${RESET}"
    
    pkg update -y 2>/dev/null || apt update -y 2>/dev/null
    
    for pkg in $DEP_PKGS; do
        echo -e "${YELLOW}  -> $pkg${RESET}"
        pkg install -y "$pkg" 2>/dev/null || apt install -y "$pkg" 2>/dev/null
    done
    
    echo -e "${GREEN}Dependencies installed${RESET}"
else
    echo -e "${GREEN}All dependencies satisfied${RESET}"
fi

# Create directories
mkdir -p "$PKT_BIN" "$PKT_SRC"

cd "$PKT_SRC"

# Clone or update
if [ -d "$PACKAGE" ]; then
    if [ "$MODE" == "update" ]; then
        echo -e "${CYAN}Updating $PACKAGE...${RESET}"
        cd "$PACKAGE"
        git pull
    else
        echo -e "${YELLOW}Source already exists, rebuilding...${RESET}"
        cd "$PACKAGE"
    fi
else
    echo -e "${CYAN}Cloning $PACKAGE...${RESET}"
    git clone --depth 1 "$REPO" "$PACKAGE"
    cd "$PACKAGE"
fi

# Build
echo -e "${CYAN}Building $PACKAGE...${RESET}"

if [ "$BUILD" == "auto" ]; then
    auto_build
    BUILD_RESULT=$?
else
    eval "$BUILD"
    BUILD_RESULT=$?
fi

if [ $BUILD_RESULT -eq 0 ]; then
    echo -e "${GREEN}Successfully installed $PACKAGE${RESET}"
    
    if [ ! -f "$PKT_INSTALLED" ]; then
        echo '{"installed":[]}' > "$PKT_INSTALLED"
    fi
    
    if ! grep -q "\"$PACKAGE\"" "$PKT_INSTALLED"; then
        sed -i "s/\[/[\"$PACKAGE\",/" "$PKT_INSTALLED"
        sed -i 's/,]/]/' "$PKT_INSTALLED"
    fi
    
    exit 0
else
    echo -e "${RED}Build failed for $PACKAGE${RESET}"
    exit 1
fi
