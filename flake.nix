{
  description = "Limit Theory - Open world space simulation game";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {git
    extra-substituters = [];
    extra-trusted-public-keys = [ ];
    allow-import-from-derivation = true;
    accept-flake-config = true;
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        lib = pkgs.lib;
        stdenv = pkgs.stdenv;


        # Development dependencies
        buildInputs = with pkgs; [
          # Core build tools
          cmake
          pkg-config

          # Languages and runtimes
          python3
          lua

          # Graphics and multimedia libraries (common for game engines)
          SDL2
          SDL2_image
          SDL2_mixer
          SDL2_ttf
          glew
          glfw

          # Audio
          openal
          freealut

          # Image processing
          libpng
          libjpeg

          # Math libraries
          glm

          # Networking (if needed)
          curl

          # Development tools
          gdb
          valgrind
          zlib
        ] ++ lib.optionals stdenv.isLinux [
          # Linux-specific dependencies
          xorg.libX11
          xorg.libXrandr
          xorg.libXinerama
          xorg.libXcursor
          xorg.libXi
          xorg.libXext
          libGL
          libGLU
        ] ++ lib.optionals stdenv.isDarwin [
          # macOS-specific dependencies
          darwin.apple_sdk.frameworks.OpenGL
          darwin.apple_sdk.frameworks.Cocoa
          darwin.apple_sdk.frameworks.IOKit
          darwin.apple_sdk.frameworks.CoreVideo
        ];

        nativeBuildInputs = with pkgs; [
          cmake
          pkg-config
          python3
          git
          git-lfs
        ];

      in
      {
        devShells.default = pkgs.mkShell {
          inherit buildInputs nativeBuildInputs;

          shellHook = ''
            echo "Limit Theory Development Environment"
            echo "=================================="
            echo ""
            echo "Available commands:"
            echo "  python configure.py        - Generate build files"
            echo "  python configure.py build  - Compile the project"
            echo "  python configure.py run    - Run the default script"
            echo ""
            echo "Make sure to initialize Git LFS if you haven't already:"
            echo "  git lfs install"
            echo ""

            # Set up environment variables for graphics libraries
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" buildInputs}:$PKG_CONFIG_PATH"

            # Ensure Python can find the configure script
            export PYTHONPATH=".:$PYTHONPATH"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation rec {
          pname = "limit-theory";
          version = "unstable";

          src = ./.;

          inherit nativeBuildInputs buildInputs;

          configurePhase = ''
            runHook preConfigure

            # Initialize Git LFS (if needed)
            git lfs install || true

            # Run the configure script
            python configure.py

            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild

            python configure.py build

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            mkdir -p $out/share/limit-theory

            # Install the main executable
            cp bin/lt64* $out/bin/ || cp bin/lt* $out/bin/ || true

            # Install scripts and resources
            cp -r script $out/share/limit-theory/ || true
            cp -r res $out/share/limit-theory/ || true

            # Create wrapper script
            cat > $out/bin/limit-theory << EOF
#!/bin/sh
cd $out/share/limit-theory
exec $out/bin/lt64 "\$@"
EOF
            chmod +x $out/bin/limit-theory

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Open world space simulation game";
            homepage = "https://github.com/JoshParnell/ltheory";
            license = licenses.unfree; # Adjust based on actual license
            platforms = platforms.unix;
            maintainers = [ ];
          };
        };

        # Utility scripts as packages
        packages.configure = pkgs.writeShellScriptBin "lt-configure" ''
          python configure.py "$@"
        '';

        packages.build = pkgs.writeShellScriptBin "lt-build" ''
          python configure.py build "$@"
        '';

        packages.run = pkgs.writeShellScriptBin "lt-run" ''
          python configure.py run "$@"
        '';
      });
}
