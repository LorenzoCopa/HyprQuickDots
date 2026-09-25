if status is-interactive
    # Starship
    starship init fish | source

    # Zoxide
    zoxide init fish | source
    # Variables
    set -gx EDITOR nvim
    set -gx VISUAL nvim

    # Alias
    alias npm="pnpm"
    alias ctest="zellij attach test || zellij -s test -n statusbar"
    alias ptest="zellij attach test1 || zellij -s test1 -n statusbar"
    alias cfish="nvim ~/Repos/HyprQuickDots/fish/config.fish"
    ## Reiniciar configuración fish
    alias rfish="source ~/.config/fish/config.fish"
end
