{pr-tracker}: {
  lib,
  pkgs,
  config,
  ...
}: let
  inherit
    (lib)
    getExe
    mkEnableOption
    mkPackageOption
    mkIf
    mkOption
    optional
    types
    ;

  inherit
    (builtins)
    toString
    ;

  inherit
    (pkgs)
    system
    ;

  cfg = config.services.pr-tracker-api;
in {
  options.services.pr-tracker-api.enable = mkEnableOption "pr-tracker-api";
  options.services.pr-tracker-api.package = mkPackageOption pr-tracker.packages.${system} "api" {};

  options.services.pr-tracker-api.user = mkOption {
    type = types.str;
    description = "User to run under.";
    default = "pr-tracker-api";
  };

  options.services.pr-tracker-api.group = mkOption {
    type = types.str;
    description = "Group to run under.";
    default = "pr-tracker-api";
  };

  options.services.pr-tracker-api.port = mkOption {
    type = types.port;
    description = "Port to listen on.";
  };

  options.services.pr-tracker-api.databaseUrl = mkOption {
    type = types.str;
    description = "URL of the database to connect to.";
    example = "postgresql:///pr-tracker?host=/run/postgresql?port=5432";
  };

  options.services.pr-tracker-api.localDb = mkOption {
    type = types.bool;
    description = "Whether database is local.";
    default = false;
  };

  config = mkIf cfg.enable {
    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      group = cfg.group;
      isSystemUser = true;
    };

    systemd.services.pr-tracker-api.description = "pr-tracker-api";
    systemd.services.pr-tracker-api.environment.PR_TRACKER_API_DATABASE_URL = cfg.databaseUrl;
    systemd.services.pr-tracker-api.environment.PR_TRACKER_API_PORT = toString cfg.port;

    systemd.services.pr-tracker-api.wantedBy = ["multi-user.target"];
    systemd.services.pr-tracker-api.after = ["network.target"] ++ optional cfg.localDb "postgresql.service";
    systemd.services.pr-tracker-api.bindsTo = optional cfg.localDb "postgresql.service";

    systemd.services.pr-tracker-api.serviceConfig.ExecStart = getExe cfg.package;
    systemd.services.pr-tracker-api.serviceConfig.User = cfg.user;
    systemd.services.pr-tracker-api.serviceConfig.Group = cfg.group;
    systemd.services.pr-tracker-api.serviceConfig.Type = "notify";
    systemd.services.pr-tracker-api.serviceConfig.Restart = "always";
  };
}
