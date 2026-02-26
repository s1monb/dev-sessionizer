function fish_prompt
    # Colors
    set -l C_PATH cyan
    set -l C_GIT green
    set -l C_KUBE magenta

    # Git branch
    set -l git_branch (command git symbolic-ref --short HEAD 2>/dev/null)
    if test -z "$git_branch"
        set git_branch (command git rev-parse --short HEAD 2>/dev/null)
    end
    set -l git_prompt ""
    if test -n "$git_branch"
        set git_prompt (set_color $C_GIT)"(git:$git_branch)"(set_color normal)""
    end

    # Current path
    set -l cwd_prompt (set_color $C_PATH)(prompt_pwd)(set_color normal)

    # Final prompt line
    echo -n (set_color blue)(__kube_prompt)(set_color $fish_color_cwd)" $git_prompt$cwd_prompt > "
end

