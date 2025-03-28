{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:arachnist/nixpkgs?ref=ar-patchset-unstable";
    disko.url = "github:arachnist/disko?ref=disko-vm-get-imageName";
  };

  outputs =
    {
      disko,
      nixpkgs,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkFormatter = system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      pkgs.writeShellApplication {
        name = "treefmt";
        text = ''treefmt "$@"'';
        runtimeInputs = [
          pkgs.deadnix
          pkgs.nixfmt-rfc-style
          pkgs.shellcheck
          pkgs.treefmt
        ];
      };
      mkVm =
        system: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            disko.nixosModules.disko
            (
              { lib, pkgs, ... }:
              {
                boot.loader.systemd-boot.enable = true;
                boot.binfmt.emulatedSystems = lib.lists.remove pkgs.system [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                services.openssh = {
                  enable = true;
                  openFirewall = true;
                  settings.PasswordAuthentication = true;
                };
                users.users.root.password = "dupa.8";
                system.stateVersion = "25.04";
                disko.devices.disk.main = {
                  imageName = "nixos-${pkgs.system}-generic-vm";
                  imageSize = "5G";
                };
                disko.imageBuilder.enableBinfmt = true;
              }
            )
          ] ++ extraModules;
        };
      mkConfigurations =
        systems: extraModules:
        nixpkgs.lib.listToAttrs (
          map (arch: (nixpkgs.lib.nameValuePair "vmtest-${arch}" (mkVm arch extraModules))) systems
        );
    in
    {
      formatter = forAllSystems mkFormatter;
      nixosConfigurations = { } // (mkConfigurations systems [ "${disko}/example/simple-efi.nix" ]);
    };
}
