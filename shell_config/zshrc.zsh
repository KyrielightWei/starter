# ---- UTF-8 Universal Check ----

# 1. 检查 locale 是否 UTF-8
if ! locale | grep -qi 'UTF-8'; then
  echo "[⚠️  WARNING] Your locale is NOT UTF-8."
  echo "  This may cause Chinese or emoji to display incorrectly."
  echo "  Current locale:"
  locale
fi

# 2. 检查中文是否能正确显示
if ! printf "中文测试" | grep -q "中文测试"; then
  echo "[⚠️  WARNING] Your terminal CANNOT display Chinese correctly."
fi

# 3. 检查是否在 tmux 内
if [[ -n "$TMUX" ]]; then
  # 检查 tmux 是否继承 UTF-8
  if ! tmux show-environment | grep -qi 'UTF-8'; then
    echo "[⚠️  WARNING] tmux did NOT inherit UTF-8 locale."
    echo "  You may need to add this to ~/.tmux.conf:"
    echo "    set -g update-environment \"LANG LC_ALL LC_CTYPE\""
  fi
fi

# ---- End UTF-8 Universal Check ----


# 进入命令前更新 tmux 窗口名
preexec() {
  if [[ -n "$TMUX" ]]; then
    tmux rename-window "$(printf '%s' "$1" | cut -d' ' -f1 | cut -c1-12) ┆ $(basename "$PWD")"
  fi
}

# 每次回到 shell prompt 时更新目录
precmd() {
  if [[ -n "$TMUX" ]]; then
    tmux rename-window "zsh ┆ $(basename "$PWD")"
  fi
}


### Zinit 初始化 ###
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

### 共享环境变量 ###
[ -f ~/.profile ] && source ~/.profile


###############################################
# 基础插件（性能优先）
###############################################

# 快速目录跳转
zinit ice lucid wait='1'
zinit light skywind3000/z.lua

# 语法高亮（fast-syntax-highlighting）
zinit ice lucid wait='0' atinit='zpcompinit'
zinit light zdharma/fast-syntax-highlighting

# 自动建议
zinit ice lucid wait="0" atload='_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions

# 补全增强
zinit ice lucid wait='0'
zinit light zsh-users/zsh-completions


###############################################
# Oh‑My‑Zsh 核心库（按依赖顺序加载）
###############################################

# OMZ 核心函数（必须最先加载）
zinit snippet OMZ::lib/functions.zsh
zinit snippet OMZ::lib/git.zsh
zinit snippet OMZ::lib/async_prompt.zsh
zinit snippet OMZ::lib/termsupport.zsh

# 其他 OMZ 基础库
zinit snippet OMZ::lib/completion.zsh
zinit snippet OMZ::lib/history.zsh
zinit snippet OMZ::lib/key-bindings.zsh
zinit snippet OMZ::lib/theme-and-appearance.zsh


###############################################
# Oh‑My‑Zsh 插件
###############################################

zinit snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh
zinit snippet OMZ::plugins/sudo/sudo.plugin.zsh
zinit snippet OMZ::plugins/svn/svn.plugin.zsh

# extract 插件（PZT）
zinit ice
zinit snippet OMZP::extract/

# git 插件（必须在所有 OMZ lib 之后）
zinit ice lucid wait='1'
zinit snippet OMZ::plugins/git/git.plugin.zsh


###############################################
# 主题
###############################################

zinit snippet OMZ::themes/ys.zsh-theme


###############################################
# NVM
###############################################

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"


# Added by CodeFuse CLI installer
export PATH="$HOME/.local/bin:$PATH"
# API key 通过 ~/.local/state/nvim/ai_keys.lua 管理，不要在此硬编码
