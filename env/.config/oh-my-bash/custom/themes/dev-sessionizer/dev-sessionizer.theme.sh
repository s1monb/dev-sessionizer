#! bash oh-my-bash.module
#
# Fish-style prompt: kubernetes context, git, cwd, and a simple suffix.

SCM_NONE_CHAR=''
SCM_THEME_PROMPT_DIRTY=" ${_omb_prompt_brown}✗"
SCM_THEME_PROMPT_CLEAN=""
SCM_THEME_PROMPT_PREFIX="${_omb_prompt_green}|"
SCM_THEME_PROMPT_SUFFIX="${_omb_prompt_green}|"
SCM_GIT_SHOW_MINIMAL_INFO=true

THEME_SHOW_CLOCK=${THEME_SHOW_CLOCK:-"false"}

OMB_PROMPT_VIRTUALENV_FORMAT='(%s) '
OMB_PROMPT_CONDAENV_FORMAT='(%s) '
OMB_PROMPT_SHOW_PYTHON_VENV=${OMB_PROMPT_SHOW_PYTHON_VENV:=true}

function _omb_theme_PROMPT_COMMAND() {
  local RC="$?"
  local python_venv _omb_prompt_white=$_omb_prompt_white
  _omb_prompt_get_python_venv
  python_venv=$_omb_prompt_white$python_venv
  local spack_env
  _omb_prompt_get_spack_env
  spack_env=$_omb_prompt_white$spack_env

  local ret_status
  if [[ ${RC} == 0 ]]; then
    ret_status="${_omb_prompt_bold_green}"
  else
    ret_status="${_omb_prompt_bold_brown}"
  fi

  history -a

  local kube_ps
  kube_ps="${_omb_prompt_blue}$(__kube_prompt)${_omb_prompt_normal}"

  PS1="$(clock_prompt)$spack_env$python_venv${kube_ps}${_omb_prompt_green}$(scm_prompt_char_info) ${_omb_prompt_cyan}\w${_omb_prompt_normal} ${ret_status}> ${_omb_prompt_normal}"
}

_omb_util_add_prompt_command _omb_theme_PROMPT_COMMAND
