{
  description = "The Clipboard Project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      systems = with flake-utils.lib.system; [
        # Add or remove systems from this list if your project can be developed on them or not
        # See https://github.com/numtide/flake-utils/blob/main/allSystems.nix for a complete list
        x86_64-linux
        aarch64-linux
        x86_64-darwin
        aarch64-darwin
      ];
    in flake-utils.lib.eachSystem systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;
        stdenv = pkgs.stdenv;

        version = self.shortRev or self.dirtyShortRev;

        # Tools for building
        nativeBuildInputs = with pkgs; [ cmake pkg-config wayland-scanner ];

        # Required libraries
        buildInputs = [ pkgs.openssl ] ++ lib.optionals stdenv.isLinux
          (with pkgs; [ libffi wayland-protocols wayland xorg.libX11 alsa-lib ])
          ++ lib.optionals stdenv.isDarwin
          [ pkgs.darwin.apple_sdk.frameworks.AppKit ];
      in {
        defaultPackage = stdenv.mkDerivation {
          pname = "clipboard-jh";
          inherit version;

          src = ./.;

          postPatch = ''
            sed -i "/CMAKE_OSX_ARCHITECTURES/d" CMakeLists.txt
          '';

          inherit nativeBuildInputs buildInputs;
          cmakeBuildType = "MinSizeRel";
          cmakeFlags = [ "-Wno-dev" "-DINSTALL_PREFIX=${placeholder "out"}" ];

          postFixup = lib.optionalString stdenv.isLinux ''
            patchelf $out/bin/cb --add-rpath $out/lib
          '';
        };

        devShell =
          pkgs.mkShellNoCC # Use mkShellNoCC to avoid gcc ending up in the environment
          {
            # Tools for building
            nativeBuildInputs = nativeBuildInputs ++ (with pkgs; [
              ninja # Required by vscode to configure cmake projects properly
              clang
            ]);

            inherit buildInputs;

            CC = "${pkgs.clang}/bin/clang";
          };
      });
}
