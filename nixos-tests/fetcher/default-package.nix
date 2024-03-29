pr-tracker: {
  pkgs,
  config,
  ...
}: let
  inherit
    (pkgs)
    system
    writeText
    ;
  pgPort = 5432;
  user = "pr-tracker";
in {
  imports = [pr-tracker.nixosModules.fetcher];

  nixpkgs.hostPlatform = system;

  services.postgresql.enable = true;
  services.postgresql.settings.port = pgPort;
  services.postgresql.ensureDatabases = [user];
  services.postgresql.ensureUsers = [
    {
      name = user;
      ensureDBOwnership = true;
    }
  ];

  services.pr-tracker.fetcher.enable = true;
  systemd.services.pr-tracker-fetcher.environment.RUST_BACKTRACE = "1";
  services.pr-tracker.fetcher.user = user;
  services.pr-tracker.fetcher.db.urlParams.host = "/run/postgresql";
  services.pr-tracker.fetcher.db.urlParams.port = toString pgPort;
  services.pr-tracker.fetcher.db.urlParams.dbname = user;
  services.pr-tracker.fetcher.db.isLocal = true;
  services.pr-tracker.fetcher.onCalendar = "*:*:*"; # every single second
  services.pr-tracker.fetcher.githubApiTokenFile = writeText "gh-auth-token" "hunter2";
  services.pr-tracker.fetcher.branchPatterns = ["*"];
  services.pr-tracker.fetcher.repo.owner = "molybdenumsoftware";
  services.pr-tracker.fetcher.repo.name = "pr-tracker";
}
