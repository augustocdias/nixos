# Neovim plugins built from flake inputs.
# All plugin inputs use the "nvim-" prefix (e.g., nvim-gitsigns).
# To update all plugins: update-neovim-plugins
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  # Map from plugin name to its flake input (accounting for nvim- prefix)
  getInput = name: inputs.${"nvim-${name}"};

  # Plugins with useFlakePackage use the flake's pre-built package output.
  # Plugins with buildFromSource need custom build logic.
  # All others are built with buildVimPlugin from their flake input source.
  pluginMeta = {
    # lazy = false means loaded eagerly; everything else loads on demand via lze
    lze = {
      lazy = false;
      useFlakePackage = true;
    };
    blink-cmp = {useFlakePackage = true;};
    blink-pairs = {useFlakePackage = true;};
    rustaceanvim = {useFlakePackage = true;};
    codesnap = {buildFromSource = true;};
    gx = {};
    plenary = {};
    nui = {};
    nvim-lspconfig = {};
    SchemaStore = {};
    nvim-treesitter-textobjects = {};
    nvim-treesitter-context = {};
    catppuccin = {};
    tokyonight = {};
    lualine = {};
    which-key = {};
    noice = {};
    nvim-notify = {};
    tabby = {};
    dropbar = {};
    auto-session = {};
    snacks = {};
    helpview = {};
    tabout = {};
    colorful-menu = {};
    gitsigns = {};
    diffview = {};
    octo = {};
    flash = {};
    trouble = {};
    todo-comments = {};
    vim-matchup = {};
    mini-icons = {};
    mini-ai = {};
    mini-files = {};
    mini-move = {};
    mini-surround = {};
    conform = {};
    nvim-lint = {};
    lightbulb = {};
    markview = {};
    gatekeeper = {};
    crates = {};
    refactoring = {};
    markdown-plus = {};
  };

  codesnap-generator = pkgs.rustPlatform.buildRustPackage {
    pname = "codesnap-generator";
    version = "unstable";
    src = getInput "codesnap";
    sourceRoot = "source/generator";
    cargoLock.lockFile = "${getInput "codesnap"}/generator/Cargo.lock";
    nativeBuildInputs = with pkgs; [pkg-config];
    buildInputs = with pkgs; [openssl];
    OPENSSL_NO_VENDOR = 1;
    doCheck = false;
  };

  disableChecks = drv:
    drv.overrideAttrs (_: {
      doCheck = false;
      doInstallCheck = false;
      dontCheckForBrokenSymlinks = true;
      nvimRequireCheck = "";
      nvimSkipModules = ["*"];
    });

  buildPlugin = name: meta: let
    src = getInput name;
  in
    if meta ? useFlakePackage
    then disableChecks (getInput name).packages.${system}.default
    else if meta ? buildFromSource && name == "codesnap"
    then
      pkgs.vimUtils.buildVimPlugin {
        pname = name;
        version = "flake";
        inherit src;
        doCheck = false;
        nvimRequireCheck = "";
        postInstall = ''
          ln -s ${codesnap-generator}/lib/libgenerator.so $out/lua/generator.so
        '';
      }
    else
      pkgs.vimUtils.buildVimPlugin {
        pname = name;
        version = "flake";
        inherit src;
        doCheck = false;
        nvimRequireCheck = "";
      };
in {
  plugins = lib.mapAttrs buildPlugin pluginMeta;

  pluginList =
    lib.mapAttrsToList (name: meta: {
      plugin = buildPlugin name meta;
      optional = meta.lazy or true;
    })
    pluginMeta;

  inherit pluginMeta;
}
