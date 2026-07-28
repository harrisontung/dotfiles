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
    enable = true;
    inherit user;
    # This machine already had a real Homebrew install (with tmux, cmux,
    # opensuperwhisper, etc.) before adopting Nix. autoMigrate hands that
    # existing /opt/homebrew installation to nix-homebrew's management
    # in place, keeping installed packages, instead of requiring a fresh
    # uninstall-and-lose-everything start.
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
      "gh"    # GitHub CLI
      "node"  # also pulls in the AXI tools' npx runtime
      "tmux"  # firstmate's default crew backend
    ];
    casks = [
      "wezterm"
      # claude-code intentionally omitted: this machine already runs the
      # native installer at ~/.local/bin/claude, and the cask would add a
      # second, competing install on PATH.
      "chromedriver"
      "cmux"                 # firstmate crew backend, tab-per-agent
      "db-browser-for-sqlite"
      "opensuperwhisper"      # local dictation; mic/accessibility already granted
    ];
  };
}
