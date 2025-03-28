{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
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
      mkFormatter = system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
      mkVm = system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            disko.nixosModules.disko
            ./modules/efi-basic.nix
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
                disko.devices.disk.vda = {
                  imageName = "nixos-${pkgs.system}-generic-vm";
                  imageSize = "5G";
                };
                disko.imageBuilder.enableBinfmt = true;
              }
            )
          ];
        };
      mkConfigurations = x: nixpkgs.lib.listToAttrs (map (arch: (nixpkgs.lib.nameValuePair "vmtest-${arch}" (mkVm arch))) x);
    in
    {
      formatter = forAllSystems mkFormatter;
      nixosConfigurations = mkConfigurations systems;
    };
}
