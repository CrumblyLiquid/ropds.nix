self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ropds;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.services.ropds = {
    enable = lib.mkEnableOption "the ropds service";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The ropds package to use.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ropds";
      description = "User under which ropds runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "ropds";
      description = "Group under which ropds runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ropds";
      description = "Directory for ropds data, libraries, and runtime configuration.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind the ropds server to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for the ropds server to listen on.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${toString cfg.host}:${toString cfg.port}";
      description = "Public base URL used for absolute links and OAuth redirect URIs";
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        Ropds configuration (translates directly to `config.toml`).
      '';
      example = lib.literalExpression ''
        {
          server = {
            base_url = "http://localhost:8081";
          };
          library = {
            root_path = "/var/lib/ropds/books";
          };
        }
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the configured port in the firewall.";
    };
  };

  config =
    let
      libraryDir = lib.attrByPath [ "library" "root_path" ] "${cfg.dataDir}/books" cfg.settings;
      coversDir = lib.attrByPath [ "covers" "covers_path" ] "${cfg.dataDir}/covers" cfg.settings;
    in
    lib.mkIf cfg.enable {
      services.ropds.settings = {
        server = {
          base_url = cfg.baseUrl;
          host = cfg.host;
          port = cfg.port;
        };
        library = {
          root_path = lib.mkDefault "${cfg.dataDir}/books";
        };
        database = {
          # TODO: Note about the `?mode=rwc` being necessary for SQLite
          url = lib.mkDefault "sqlite://${cfg.dataDir}/ropds.db?mode=rwc";
        };
        opds = { };
        scanner = { };
      };

      users.users = lib.mkIf (cfg.user == "ropds") {
        ropds = {
          isSystemUser = true;
          group = cfg.group;
          home = cfg.dataDir;
          createHome = true;
          description = "ropds service user";
        };
      };

      users.groups = lib.mkIf (cfg.group == "ropds") {
        ropds = { };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

      systemd.services.ropds = {
        description = "ropds OPDS Server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        path = [
          pkgs.poppler-utils
          pkgs.djvulibre
        ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;

          ExecStartPre =
            let
              configFile = tomlFormat.generate "ropds-config.toml" cfg.settings;
            in
            [
              "+${pkgs.coreutils}/bin/install -m 600 -o ${cfg.user} -g ${cfg.group} ${configFile} ${cfg.dataDir}/config.toml"
            ];

          ExecStart = "${lib.getExe cfg.package}";
          Restart = "on-failure";
          RestartSec = "5s";

          # Filesystem
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateMounts = true;

          # TODO: Database will be inaccessible if it's not inside the WorkingDirectory
          ReadWritePaths = [
            cfg.dataDir
            libraryDir
            coversDir
          ];

          UMask = "0077";

          # Kernel
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";

          # Privileges
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          RemoveIPC = true;
          KeyringMode = "private";

          # Devices
          PrivateDevices = true;
          DevicePolicy = "closed";

          # Network
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];

          # Syscalls
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "~@resources"
          ];
          SystemCallArchitectures = "native";

          # Other
          MemoryDenyWriteExecute = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
        };
      };
    };
}
