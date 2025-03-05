# Eruption for NixOS

A nix derivation and relating services to run [eruption](https://github.com/eruption-project/eruption) on NixOS.

## Configuration

To set eruption up on NixOS you need to add the following to your nixos `configuration.nix`:

```nix
{ config, pkgs, ... }:
let
  eruption = import fetchFromGithub {
    owner = "PucklaJ";
    repo = "eruption-nix";
    rev = "sdlokfjsdoikfsfikosfoiksdjfoiksdfjsikfj";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
  };
in
{
  # D-Bus is required for the org.eruption dbus service
  services.dbus.enable = true;
  services.dbus.packages = [
    eruption.eruption
  ];

  # PolicyKit is needed to authentication of the dbus service
  security.polkit.enable = true;

  # udev for the custom udev rules
  services.udev.enable = true;
  services.udev.packages = [
    gtk3
    eruption.eruption
  ];

  # Install the binaries eruption, eruptionctl etc.
  # This also installs the polkit actions required for dbus authentication
  environment.systemPackages = [
    eruption.eruption
  ];

  # Some files need to be set up directly on the root filesystem
  environment.etc = eruption.etc // {
  };
  environment.variables = {
    GSETTINGS_SCHEMA_DIR = "${pkgs.gtk3}/share/gsettings-schemas/gtk+3-${pkgs.gtk3.version}/glib-2.0/schemas";
  };
  systemd.services = eruption.system_services // {
  };
  systemd.user.services = eruption.user_services // {
  };
}
```

Since currently the `eruption-install-files.service` removes the `/var/lib/eruption/profiles` folder a separate service to setup a modified profile is necessary:

```nix
  ...

  systemd.services = eruption.system_services // {
    "setup-eruption-profile" = {
      description = "Setup current profile for Eruption";
      after = [ "network.target" ];
      before = [ "eruption.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        mkdir -p /var/lib/eruption/profiles
        ln -sf /path/to/profile-name.profile.state /var/lib/eruption/profiles/
      '';
      enable = true;
    };
  };

  ...
```