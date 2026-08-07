{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  # Home Manager's manpage builder generates options.json with an uncontexted
  # nixpkgs store path, which Nix warns about on every switch.
  # See https://github.com/nix-community/home-manager/issues/7935
  # Costs `man home-configuration.nix`; the same docs are online.
  manual.manpages.enable = false;

  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    git
    gnupg     # commit signing
    # gnu tools under g-prefixes (gtimeout, gshuf), so BSD ls/date stay intact
    coreutils-prefixed
    # c/c++ toolchain
    cmake
    automake  # autotools, for ./configure-style third-party sources
    libtool
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  # Versioned Homebrew formulae are keg-only, so psql/pg_dump are never linked
  # into /opt/homebrew/bin. `brew link` works but gets undone; declare it instead.
  home.sessionPath = [
    "/opt/homebrew/opt/postgresql@17/bin"
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    # Written to .zprofile, which runs before .zshrc. brew shellenv has to come
    # first: rbenv lives in /opt/homebrew/bin and would not be found otherwise.
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
      eval "$(rbenv init - --no-rehash zsh)"
    '';
    initContent = ''
      bindkey '^f' autosuggest-accept

      # Conda is the single source of truth for Python on this machine.
      # Kept here rather than in ~/.zshrc, which home-manager regenerates.
      __conda_setup="$('/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
      if [ $? -eq 0 ]; then
          eval "$__conda_setup"
      else
          if [ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]; then
              . "/opt/anaconda3/etc/profile.d/conda.sh"
          else
              export PATH="/opt/anaconda3/bin:$PATH"
          fi
      fi
      unset __conda_setup
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Kien Huynh";
        email = "143785443+kienthuynh@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      # Was `vim` in the hand-written ~/.gitconfig, which silently overrode
      # $EDITOR and opened vim for commit messages.
      core.editor = "nvim";
    };
    # Replaces both the old ~/.gitignore_global and ~/.config/git/ignore.
    ignores = [
      ".DS_Store"
      "**/.claude/settings.local.json"
    ];
  };

  # Conda owns its own state; this is the one bit worth pinning. Base stays
  # unactivated so no "(base)" prefix appears in projects that do not need it.
  home.file.".condarc".text = ''
    channels:
      - defaults
    auto_activate_base: false
  '';

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
