{ lib }:
{
  # Returns all subdirectories of a path
  allDirs =
    dir:
    let
      names = builtins.attrNames (builtins.readDir dir);
      subdirs = builtins.filter (sub: builtins.readFileType (dir + "/${sub}") == "directory") names;
    in
    map (sub: dir + "/${sub}") subdirs;

  # Auto-imports all .nix files (except default.nix) and all subdirectories with default.nix
  autoImport =
    dir:
    let
      entries = builtins.readDir dir;
      files = builtins.filter (
        f: f != "default.nix" && lib.hasSuffix ".nix" f && entries.${f} == "regular"
      ) (builtins.attrNames entries);
      subdirs = builtins.filter (
        d: entries.${d} == "directory" && builtins.pathExists (dir + "/${d}/default.nix")
      ) (builtins.attrNames entries);
    in
    map (f: dir + "/${f}") files ++ map (d: dir + "/${d}") subdirs;
}
