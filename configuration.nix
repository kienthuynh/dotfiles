{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = false;
    inherit user;
  };
  homebrew = {
    enable = true;
    # Enforcing, not merely additive: anything installed but not listed below is
    # removed on every switch. Forces ad-hoc `brew install`s to be declared here
    # instead of silently accumulating. See the Homebrew warning in README.md.
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = false;
    onActivation.extraFlags = [ "--force" ];
    # Only things Homebrew genuinely does better than nixpkgs live here.
    brews = [
      "herdr"          # nixpkgs lags behind (0.7.5 vs 0.8.0)
      "postgresql@17"  # brew services is the simplest launchd story on macOS
      "rbenv"          # exact Ruby pins per .ruby-version; nixpkgs has no 3.2.x
      "ruby-build"     # not packaged in nixpkgs; rbenv needs it to build Rubies
      # rbenv compiles Rubies against Homebrew libs, but Homebrew cannot see that
      # dependency. Undeclared, `brew autoremove` (and `cleanup = "zap"`) delete
      # gmp and every rbenv Ruby dies with a dyld "Library not loaded" error.
      # ruby-build already pulls in openssl@3/readline/libyaml; gmp it does not.
      "gmp"
    ];
    casks = [
      "wezterm"
      "claude-code"
    ];
  };
}
