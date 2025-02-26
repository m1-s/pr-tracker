{inputs, ...}: {
  imports = [
    inputs.treefmt-nix.flakeModule
  ];
  perSystem.treefmt = {
    projectRootFile = "flake.nix";
    programs = {
      alejandra.enable = true;
      prettier.enable = true;
      toml-sort = {
        enable = true;
        all = true;
      };
    };
  };
}
