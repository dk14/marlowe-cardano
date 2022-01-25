{ runCommand, fix-prettier, src, lib, diffutils, glibcLocales }:
let
  # just JavaScript, HTML, and CSS sources
  src' = lib.cleanSourceWith {
    inherit src;
    filter = with lib;
      name: type:
        let baseName = baseNameOf (toString name); in
        (
          (type == "regular" && hasSuffix ".js" baseName) ||
          (type == "regular" && hasSuffix ".ts" baseName) ||
          (type == "regular" && hasSuffix ".html" baseName) ||
          (type == "regular" && hasSuffix ".css" baseName) ||
          (type == "directory" && (baseName != "generated"
          && baseName != "output"
          && baseName != "node_modules"
          && baseName != ".spago"))
        );
  };
in
runCommand "prettier-check"
{
  buildInputs = [ fix-prettier diffutils glibcLocales ];
} ''
  set +e
  cp -a ${src'} orig
  cp -a ${src'} prettier
  chmod -R +w prettier
  cd prettier
  fix-prettier
  cd ..
  diff --brief --recursive orig prettier > /dev/null
  EXIT_CODE=$?
  if [[ $EXIT_CODE != 0 ]]
  then
    mkdir -p $out/nix-support
    diff -ur orig prettier > $out/prettier.diff
    echo "file none $out/prettier.diff" > $out/nix-support/hydra-build-products
    echo "*** prettier found changes that need addressed first"
    echo "*** Please run \`nix-shell --run fix-prettier\` and commit changes"
    echo "*** or apply the diff generated by hydra if you don't have nix."
    exit $EXIT_CODE
  else
    echo $EXIT_CODE > $out
  fi
''