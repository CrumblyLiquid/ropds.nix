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
        See upstream `config.toml.example` for all options.

        Values end up world-readable in the Nix store.
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

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/ropds-admin-password";
      description = ''
        File containing the password of the `admin` user.
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
      dbUrl = cfg.settings.database.url;
      dbScheme = if builtins.isString dbUrl then builtins.head (lib.splitString ":" dbUrl) else null;
      absPath = p: if lib.hasPrefix "/" p then p else "${cfg.dataDir}/${p}";
      writableDirs =
        let
          sqlitePath = absPath (
            builtins.head (lib.splitString "?" (lib.removePrefix "//" (lib.removePrefix "sqlite:" dbUrl)))
          );
        in
        lib.unique (
          [
            cfg.dataDir
            (absPath cfg.settings.library.root_path)
            (absPath cfg.settings.covers.covers_path)
          ]
          ++ lib.optional (cfg.settings.upload.allow_upload or false) (
            absPath cfg.settings.upload.upload_path
          )
          ++ lib.optional (dbScheme == "sqlite") (dirOf sqlitePath)
        );
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
        covers = {
          covers_path = lib.mkDefault "${cfg.dataDir}/covers";
        };
        upload = {
          upload_path = lib.mkDefault "${cfg.dataDir}/uploads";
        };
        database = {
          # `mode=rwc` makes sqlx create the database file if it's missing.
          url = lib.mkDefault "sqlite://${cfg.dataDir}/ropds.db?mode=rwc";
        };
        opds = { };
        scanner = { };
      };

      warnings = lib.optional (dbScheme == "sqlite" && !lib.hasInfix "mode=rwc" dbUrl) ''
        services.ropds.settings.database.url is a SQLite URL without `?mode=rwc`;
        the database file will not be created if it doesn't exist yet.
      '';

      users.users = lib.mkIf (cfg.user == "ropds") {
        ropds = {
          isSystemUser = true;
          group = cfg.group;
          home = cfg.dataDir;
          description = "ropds service user";
        };
      };

      systemd.tmpfiles.rules = map (dir: "d '${dir}' 0750 ${cfg.user} ${cfg.group} - -") writableDirs;

      users.groups = lib.mkIf (cfg.group == "ropds") {
        ropds = { };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

      systemd.services.ropds =
        let
          dbUnits =
            lib.optional (
              lib.elem dbScheme [
                "postgres"
                "postgresql"
              ]
              && config.services.postgresql.enable
            ) "postgresql.target"
            ++ lib.optional (
              lib.elem dbScheme [
                "mysql"
                "mariadb"
              ]
              && config.services.mysql.enable
            ) "mysql.service";
        in
        {
          description = "ropds OPDS Server";
          after = [ "network.target" ] ++ dbUnits;
          requires = dbUnits;
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
                # TODO: Secrets can only be set through `settings`
                # which means they're visible in the Nix store.
                configFile = tomlFormat.generate "ropds-config.toml" cfg.settings;

                # TODO: ropds only accepts the password as a CLI argument
                # which means it's briefly visible in the process list
                setAdminScript = pkgs.writeShellScript "ropds-set-admin" ''
                  set -euo pipefail
                  ${lib.getExe cfg.package} --config ${cfg.dataDir}/config.toml \
                    --set-admin "$(< "$CREDENTIALS_DIRECTORY/admin_password")"
                '';
              in
              [
                "${pkgs.coreutils}/bin/install -m 600 ${configFile} ${cfg.dataDir}/config.toml"
              ]
              ++ lib.optional (cfg.adminPasswordFile != null) setAdminScript;

            LoadCredential = lib.optional (
              cfg.adminPasswordFile != null
            ) "admin_password:${cfg.adminPasswordFile}";

            ExecStart = "${lib.getExe cfg.package} --config ${cfg.dataDir}/config.toml";
            Restart = "on-failure";
            RestartSec = "5s";

            # Filesystem
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateMounts = true;

            ReadWritePaths = writableDirs;

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
