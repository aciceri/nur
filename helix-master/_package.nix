# Stolen and adapted from https://github.com/helix-editor/helix/blob/master/default.nix
{
  rustPlatform,
  callPackage,
  runCommand,
  installShellFiles,
  git,
  gitRev ? null,
  grammarOverlays ? [ ],
  includeGrammarIf ? _: true,
  fetchFromGitHub,
  nix-update-script,
  helix,
  lib,
}:
let
  helixSource = fetchFromGitHub {
    owner = "helix-editor";
    repo = "helix";
    rev = "10c6a100c6e93b0dc175bf2f8b5a1afd66aebe2a";
    hash = "sha256-HqVZwIwpDviDB1daJY/pPzkMKAC+dj5y0rDWEJbuKsE=";
  };

  grammars = callPackage ./_grammars.nix { inherit grammarOverlays includeGrammarIf helixSource; };

  runtimeDir = runCommand "helix-runtime" { } ''
    mkdir -p $out
    ln -s ${helixSource}/runtime/* $out
    rm -r $out/grammars
    ln -s ${grammars} $out/grammars
  '';
in
rustPlatform.buildRustPackage (self: {
  cargoLock = {
    lockFile = "${helixSource}/Cargo.lock";
  };

  propagatedBuildInputs = [ runtimeDir ];

  nativeBuildInputs = [
    installShellFiles
    git
  ];

  buildType = "release";

  name = with builtins; (fromTOML (readFile "${helixSource}/helix-term/Cargo.toml")).package.name;
  version = "master-${helixSource.rev}";
  pname = "helix-master";
  src = helixSource;

  HELIX_DISABLE_AUTO_GRAMMAR_BUILD = "1";

  HELIX_NIX_BUILD_REV = gitRev;

  doCheck = false;
  strictDeps = true;

  env.HELIX_DEFAULT_RUNTIME = runtimeDir;

  postInstall = ''
    mkdir -p $out/lib
    installShellCompletion ${helixSource}/contrib/completion/hx.{bash,fish,zsh}
    mkdir -p $out/share/{applications,icons/hicolor/{256x256,scalable}/apps}
    cp ${helixSource}/contrib/Helix.desktop $out/share/applications/Helix.desktop
    cp ${helixSource}/logo.svg $out/share/icons/hicolor/scalable/apps/helix.svg
    cp ${helixSource}/contrib/helix.png $out/share/icons/hicolor/256x256/apps/helix.png
  '';

  meta = {
    inherit (helix.meta)
      description
      homepage
      license
      mainProgram
      ;
    maintainers = [ lib.maintainers.aciceri ];
  };

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [ "--version=branch" ];
    };
  };
})
