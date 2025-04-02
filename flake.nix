{
  description = "disko/vm playground";

  inputs = {
    nixpkgs.url = "github:arachnist/nixpkgs?ref=ar-patchset-unstable";
    disko.url = "github:arachnist/disko?ref=disko-vm-get-imageName";
    # disko.url = "git+file:///home/ar/scm/disko";
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
      mkFormatter =
        system:
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
        baseName: system: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            disko.nixosModules.disko
            (
              { lib, pkgs, ... }:
              {
                boot.loader.systemd-boot.enable = lib.mkDefault true;
                boot.binfmt.emulatedSystems = lib.lists.remove pkgs.system [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                services.openssh = {
                  enable = lib.mkDefault true;
                  openFirewall = lib.mkDefault true;
                };
                system.stateVersion = "25.04";
                disko.devices.disk.main.imageName = "${baseName}-${pkgs.system}";
                disko.imageBuilder.enableBinfmt = false;
              }
            )
          ] ++ extraModules;
        };
      mkConfigurations =
        baseName: systems: extraModules:
        nixpkgs.lib.listToAttrs (
          map (
            arch: (nixpkgs.lib.nameValuePair "${baseName}-${arch}" (mkVm baseName arch extraModules))
          ) systems
        );
    in
    {
      formatter = forAllSystems mkFormatter;
      nixosConfigurations =
        { }
        // (mkConfigurations "disko-basic" systems [
          "${disko}/example/simple-efi.nix"
          (
            { ... }:
            {
              users.users.root.password = "dupa.8";
              disko.devices.disk.main.imageSize = "5G";
              services.openssh.settings.PasswordAuthentication = true;
            }
          )
        ])
        // (mkConfigurations "tmpfs" systems [
          (
            { ... }:
            {
              disko.devices = {
                nodev."/" = {
                  fsType = "tmpfs";
                  mountOptions = [
                    "size=8G"
                    "defaults"
                    "mode=755"
                  ];
                };
                disk.main = {
                  type = "disk";
                  content = {
                    type = "gpt";
                    partitions = {
                      ESP = {
                        name = "ESP";
                        size = "1G";
                        type = "EF00";
                        content = {
                          type = "filesystem";
                          format = "vfat";
                          mountpoint = "/boot";
                          mountOptions = [ "umask=0077" ];
                        };
                      };
                      persist = {
                        size = "100%";
                        content = {
                          type = "btrfs";
                          mountpoint = "/persist";
                          subvolumes = {
                            "/home" = {
                              mountOptions = [ "compress=zstd" ];
                              mountpoint = "/home";
                            };
                            "/nix" = {
                              mountOptions = [
                                "compress=zstd"
                                "noatime"
                              ];
                              mountpoint = "/nix";
                            };
                          };
                        };
                      };
                    };
                  };
                };
              };
            }
          )
          (
            { ... }:
            {
              users.users.root.password = "dupa.8";
              disko.devices.disk.main.imageSize = "5G";
              services.openssh.settings.PasswordAuthentication = true;
            }
          )
        ]);
    };
}
