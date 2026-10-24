{
  description = "acer: command-line control for Acer Nitro / Predator laptops";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: {
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "acer-sense-cli";
          version = "0.1.0";
          src = self;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [ pkgs.bash ];
          makeFlags = [ "PREFIX=$(out)" ];
          doCheck = true;
          nativeCheckInputs = [ pkgs.shellcheck ];
          checkTarget = "test";
          preCheck = "patchShebangs acer tests";
          postFixup = ''
            wrapProgram $out/bin/acer --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils ]}
          '';
          meta = {
            description = "Command-line control for Acer Nitro / Predator laptops (Linuwu-Sense)";
            homepage = "https://github.com/muralibaburaj/acer-sense-cli";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.linux;
            mainProgram = "acer";
          };
        };
      });
    };
}
