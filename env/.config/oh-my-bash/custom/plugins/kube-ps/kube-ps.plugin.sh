#! bash oh-my-bash.module

kube_ps() {
  case "${1-}" in
    on) export __KUBE_PS_ENABLED=1 ;;
    off) export __KUBE_PS_ENABLED=0 ;;
  esac
}

__kube_ps_stat_mtime() {
  python -c "print(__import__('os').stat(__import__('sys').argv[1]).st_mtime)" "$1" 2>/dev/null
}

__kube_ps_cache_context() {
  local ctx
  if ctx=$(kubectl config current-context 2>/dev/null); then
    __kube_ps_context=$ctx
  else
    __kube_ps_context='n/a'
  fi
}

__kube_ps_cache_namespace() {
  local ns
  ns=$(kubectl config view --minify -o 'jsonpath={..namespace}' 2>/dev/null)
  if [[ -n $ns ]]; then
    __kube_ps_namespace=$ns
  else
    __kube_ps_namespace=default
  fi
}

__kube_ps_refresh() {
  local kubeconfig=$1
  __kube_ps_cache_context
  __kube_ps_cache_namespace
  __kube_ps_kubeconfig=$kubeconfig
  __kube_ps_timestamp=$(date +%s)
}

__kube_ps_update_cache() {
  local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
  local -a configs=()
  local conf mtime

  if [[ -n ${KUBECONFIG-} ]]; then
    IFS=':' read -r -a configs <<< "$kubeconfig"
  else
    configs=("$kubeconfig")
  fi

  if [[ "$kubeconfig" != "${__kube_ps_kubeconfig-}" ]]; then
    __kube_ps_refresh "$kubeconfig"
    return
  fi

  for conf in "${configs[@]}"; do
    [[ -r $conf ]] || continue
    mtime=$(__kube_ps_stat_mtime "$conf") || continue
    if [[ -z ${__kube_ps_timestamp-} ]] ||
      python -c "import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)" "$mtime" "${__kube_ps_timestamp:-0}"; then
      __kube_ps_refresh "$kubeconfig"
      return
    fi
  done
}

__kube_prompt() {
  [[ ${__KUBE_PS_ENABLED:-0} == 1 ]] || return 0
  command -v kubectl &>/dev/null || return 0

  __kube_ps_update_cache
  printf $' (\u2388 %s|%s)' "${__kube_ps_context:-n/a}" "${__kube_ps_namespace:-default}"
}
