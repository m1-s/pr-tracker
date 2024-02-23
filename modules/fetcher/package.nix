{pr-tracker}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (builtins)
    concatStringsSep
    toJSON
    ;

  inherit
    (lib)
    attrsToList
    escapeShellArg
    escapeURL
    getExe
    mkEnableOption
    mkPackageOption
    mkIf
    mkOption
    types
    optional
    ;

  inherit
    (pkgs)
    system
    urlencode
    ;

  cfg = config.services.pr-tracker-fetcher;
in {
  options.services.pr-tracker-fetcher.enable = mkEnableOption "pr-tracker-fetcher";
  options.services.pr-tracker-fetcher.package = mkPackageOption pr-tracker.packages.${system} "fetcher" {};

  options.services.pr-tracker-fetcher.user = mkOption {
    type = types.str;
    description = "User to run under.";
    default = "pr-tracker-fetcher";
  };

  options.services.pr-tracker-fetcher.group = mkOption {
    type = types.str;
    description = "Group to run under.";
    default = "pr-tracker-fetcher";
  };

  options.services.pr-tracker-fetcher.branchPatterns = mkOption {
    type = types.listOf types.str;
    description = "List of branch patterns to track.";
    example = ["release-*"];
  };

  options.services.pr-tracker-fetcher.dbUrlParams = mkOption {
    type = types.attrsOf types.str;
    description = "URL parameters to compose the database URL from.";
    example = {
      user = "pr-tracker";
      host = "localhost";
      port = "5432";
      dbname = "pr-tracker";
    };
  };

  options.services.pr-tracker-fetcher.dbPasswordFile = mkOption {
    type = types.nullOr types.path;
    description = "Path to a file containing the database password.";
    example = "/run/secrets/db-password";
    default = null;
  };

  options.services.pr-tracker-fetcher.localDb = mkOption {
    type = types.bool;
    description = "Whether database is local.";
    default = false;
  };

  options.services.pr-tracker-fetcher.githubApiTokenFile = mkOption {
    type = types.path;
    description = "Path to a file containing a GitHub API token.";
    example = "/run/secrets/github-api.token";
  };

  options.services.pr-tracker-fetcher.repo.owner = mkOption {
    type = types.str;
    description = "Owner of the GitHub repository to track.";
    example = "NixOS";
  };

  options.services.pr-tracker-fetcher.repo.name = mkOption {
    type = types.str;
    description = "Name of the GitHub repository to track.";
    example = "nixpkgs";
  };

  options.services.pr-tracker-fetcher.onCalendar = mkOption {
    type = types.str;
    description = lib.mdDoc ''
      When to run the fetcher. This is a systemd timer `OnCalendar` string, see
      {manpage}`systemd.time(7)` for a full specification.";
    '';
    example = "daily";
  };

  config = mkIf cfg.enable {
    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      group = cfg.group;
      isSystemUser = true;
    };

    systemd.timers.pr-tracker-fetcher.timerConfig.OnCalendar = cfg.onCalendar;
    systemd.timers.pr-tracker-fetcher.wantedBy = ["timers.target"];

    systemd.services.pr-tracker-fetcher.description = "pr-tracker-fetcher";
    systemd.services.pr-tracker-fetcher.after = ["network.target"] ++ optional cfg.localDb "postgresql.service";
    systemd.services.pr-tracker-fetcher.requires = optional cfg.localDb "postgresql.service";
    systemd.services.pr-tracker-fetcher.script = let
      databaseUrl = let
        pairs = map (param: "${escapeURL param.name}=${escapeURL param.value}") (attrsToList cfg.dbUrlParams);
        params = concatStringsSep "&" pairs;
      in "postgresql://?${params}";

      passwordFile = optional (cfg.dbPasswordFile != null) ''
        PASSWORD=$(${getExe urlencode} --encode-set component < ${cfg.dbPasswordFile})
        PR_TRACKER_FETCHER_DATABASE_URL="$PR_TRACKER_FETCHER_DATABASE_URL&password=$PASSWORD"
      '';
    in
      concatStringsSep "\n" (
        [
          "export PR_TRACKER_FETCHER_DATABASE_URL=${escapeShellArg databaseUrl}"
          "export PR_TRACKER_FETCHER_GITHUB_REPO_OWNER=${escapeShellArg cfg.repo.owner}"
          "export PR_TRACKER_FETCHER_GITHUB_REPO_NAME=${escapeShellArg cfg.repo.name}"
          "export PR_TRACKER_FETCHER_BRANCH_PATTERNS=${escapeShellArg (toJSON cfg.branchPatterns)}"
          "export PR_TRACKER_FETCHER_GITHUB_TOKEN=$(< ${cfg.githubApiTokenFile})"
          # CACHE_DIRECTORY is set by systemd based on the CacheDirectory setting.
          # See https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#RuntimeDirectory=
          "export PR_TRACKER_FETCHER_CACHE_DIR=$CACHE_DIRECTORY"
        ]
        ++ passwordFile
        ++ ["exec ${getExe cfg.package}"]
      );

    systemd.services.pr-tracker-fetcher.serviceConfig.User = cfg.user;
    systemd.services.pr-tracker-fetcher.serviceConfig.Group = cfg.group;
    systemd.services.pr-tracker-fetcher.serviceConfig.Type = "oneshot";
    systemd.services.pr-tracker-fetcher.serviceConfig.Restart = "on-failure";
    systemd.services.pr-tracker-fetcher.serviceConfig.CacheDirectory = "pr-tracker-fetcher";
  };
}
