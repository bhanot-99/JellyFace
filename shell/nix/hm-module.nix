self: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  cli-default = self.inputs.caelestia-cli.packages.${system}.default;
  shell-default = self.packages.${system}.with-cli;

  cfg = config.programs.jellyface;
in {
  imports = [
    (lib.mkRenamedOptionModule ["programs" "jellyface" "environment"] ["programs" "jellyface" "systemd" "environment"])
  ];
  options = with lib; {
    programs.jellyface = {
      enable = mkEnableOption "Enable JellyFace shell";
      package = mkOption {
        type = types.package;
        default = shell-default;
        description = "The package of JellyFace shell";
      };
      systemd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable the systemd service for JellyFace shell";
        };
        target = mkOption {
          type = types.str;
          description = ''
            The systemd target that will automatically start the JellyFace shell.
          '';
          default = config.wayland.systemd.target;
        };
        environment = mkOption {
          type = types.listOf types.str;
          description = "Extra Environment variables to pass to the JellyFace shell systemd service.";
          default = [];
          example = [
            "QT_QPA_PLATFORMTHEME=gtk3"
          ];
        };
      };
      settings = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "JellyFace shell settings";
      };
      extraConfig = mkOption {
        type = types.str;
        default = "";
        description = "JellyFace shell extra configs written to shell.json";
      };
      cli = {
        enable = mkEnableOption "Enable JellyFace CLI";
        package = mkOption {
          type = types.package;
          default = cli-default;
          description = "The package of JellyFace CLI"; # Doesn't override the shell's CLI, only change from home.packages
        };
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = "JellyFace CLI settings";
        };
        extraConfig = mkOption {
          type = types.str;
          default = "";
          description = "JellyFace CLI extra configs written to cli.json";
        };
      };
    };
  };

  config = let
    cli = cfg.cli.package;
    shell = cfg.package;
  in
    lib.mkIf cfg.enable {
      systemd.user.services.jellyface = lib.mkIf cfg.systemd.enable {
        Unit = {
          Description = "JellyFace Shell Service";
          After = [cfg.systemd.target];
          PartOf = [cfg.systemd.target];
          X-Restart-Triggers = lib.mkIf (cfg.settings != {}) [
            "${config.xdg.configFile."jellyface/shell.json".source}"
          ];
        };

        Service = {
          Type = "exec";
          ExecStart = "${shell}/bin/JellyFace";
          Restart = "on-failure";
          RestartSec = "5s";
          TimeoutStopSec = "5s";
          Environment =
            [
              "QT_QPA_PLATFORM=wayland"
            ]
            ++ cfg.systemd.environment;

          Slice = "session.slice";
        };

        Install = {
          WantedBy = [cfg.systemd.target];
        };
      };

      xdg.configFile = let
        mkConfig = c:
          lib.pipe (
            if c.extraConfig != ""
            then c.extraConfig
            else "{}"
          ) [
            builtins.fromJSON
            (lib.recursiveUpdate c.settings)
            builtins.toJSON
          ];
        shouldGenerate = c: c.extraConfig != "" || c.settings != {};
      in {
        "jellyface/shell.json" = lib.mkIf (shouldGenerate cfg) {
          text = mkConfig cfg;
        };
        "jellyface/cli.json" = lib.mkIf (shouldGenerate cfg.cli) {
          text = mkConfig cfg.cli;
        };
      };

      home.packages = [shell] ++ lib.optional cfg.cli.enable cli;
    };
}
