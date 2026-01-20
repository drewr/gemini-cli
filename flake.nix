{
  description = "Gemini CLI package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/32f313e49e42f715491e1ea7b306a87c16fe0388";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = self.packages.${system}.gemini-cli;

          gemini-cli = pkgs.buildNpmPackage (finalAttrs: {
            pname = "gemini-cli";
            version = "0.24.4";

            src = pkgs.fetchFromGitHub {
              owner = "google-gemini";
              repo = "gemini-cli";
              tag = "v${finalAttrs.version}";
              hash = "sha256-aNVy/4ofqW1ILn4u6BFuIj5fKTXx4J5n1SqpKJQyOxA=";
            };

            nodejs = pkgs.nodejs_22;
            npmDepsHash = "sha256-gtfrdS4iqmB0V7nhVttIqlO4H/ZbCi+ofHld5guIzlw=";

            nativeBuildInputs = [ pkgs.jq pkgs.pkg-config ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.clang_20 ];

            buildInputs = [ pkgs.ripgrep pkgs.libsecret ];

            preConfigure = ''
              mkdir -p packages/generated
              echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > packages/generated/git-commit.ts
            '';

            postPatch = ''
              ${pkgs.jq}/bin/jq 'del(.optionalDependencies."node-pty")' package.json > package.json.tmp && mv package.json.tmp package.json
              ${pkgs.jq}/bin/jq 'del(.optionalDependencies."node-pty")' packages/core/package.json > packages/core/package.json.tmp && mv packages/core/package.json.tmp packages/core/package.json
              substituteInPlace packages/core/src/tools/ripGrep.ts \
                --replace-fail "await ensureRgPath();" "'${pkgs.lib.getExe pkgs.ripgrep}';"
              sed -i '/disableAutoUpdate: {/,/}/ s/default: false/default: true/' packages/cli/src/config/settingsSchema.ts
              substituteInPlace packages/cli/src/utils/handleAutoUpdate.ts \
                --replace-fail "settings.merged.general?.disableAutoUpdate ?? false" "settings.merged.general?.disableAutoUpdate ?? true" \
                --replace-fail "settings.merged.general?.disableAutoUpdate" "(settings.merged.general?.disableAutoUpdate ?? true)"
              substituteInPlace packages/cli/src/ui/utils/updateCheck.ts \
                --replace-fail "settings.merged.general?.disableUpdateNag" "(settings.merged.general?.disableUpdateNag ?? true)"
            '';

            disallowedReferences = [ finalAttrs.npmDeps pkgs.nodejs_22.python ];

            installPhase = ''
              runHook preInstall
              mkdir -p $out/{bin,share/gemini-cli/node_modules/@google}
              npm prune --omit=dev
              rm node_modules/shell-quote/print.py
              cp -r node_modules $out/share/gemini-cli/
              rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli*
              rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion
              cp -r packages/cli $out/share/gemini-cli/node_modules/@google/gemini-cli
              cp -r packages/core $out/share/gemini-cli/node_modules/@google/gemini-cli-core
              cp -r packages/a2a-server $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
              rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md
              ln -s $out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js $out/bin/gemini
              chmod +x "$out/bin/gemini"
              runHook postInstall
            '';

            passthru.updateScript = pkgs.nix-update-script { };

            meta = {
              description = "AI agent that brings the power of Gemini directly into your terminal";
              homepage = "https://github.com/google-gemini/gemini-cli";
              license = pkgs.lib.licenses.asl20;
              sourceProvenance = with pkgs.lib.sourceTypes; [ fromSource ];
              maintainers = with pkgs.lib.maintainers; [ ];
              platforms = pkgs.lib.platforms.all;
              mainProgram = "gemini";
            };
          });
        });
    };
}
