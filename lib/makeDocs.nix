{modules, filter, pkgs}:
with pkgs;
let
  nixosConfiguration = lib.evalModules { inherit modules; };
  docs = pkgs.nixosOptionsDoc {
    inherit pkgs lib;
    inherit (nixosConfiguration) options;
    warningsAreErrors = false;
  };
  filteredOptions = lib.filterAttrs filter docs.optionsNix;
  optionsJSON = pkgs.writeText "options.json" (builtins.unsafeDiscardStringContext (builtins.toJSON filteredOptions));
  optionsMarkdown =
    pkgs.runCommand "options.md" {} ''
                ${pkgs.python3Minimal}/bin/python ${pkgs.path}/nixos/lib/make-options-doc/generateCommonMark.py \
                < ${optionsJSON} \
                > $out
            '';
in {
  inherit optionsJSON optionsMarkdown;
  all = pkgs.linkFarm "docs" [ { name = "options.json"; path = optionsJSON; } { name = "options.md"; path = optionsMarkdown; } ];
}
