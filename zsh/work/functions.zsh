# Work-specific shell functions — only sourced when installed with --work.

# Claude Code shortcut — opens in Common-Automation with full permissions
colo() {
  cd /home/heaton/astra/Common-Automation && claude --dangerously-skip-permissions "$@"
}

# Copilot yolo shortcut
yolo() {
  copilot --yolo --resume "$@"
}

# =========================================================
# Azure helpers
# =========================================================

# Loads AZ_TENANT_ID and AZ_SUBSCRIPTION_ID from ~/.zsh/work/az.env
_az_load_ids() {
  if [[ -z "${AZ_ENV_FILE:-}" ]]; then
    AZ_ENV_FILE="$ZDOTDIR/work/az.env"
  fi
  if [[ ! -f "$AZ_ENV_FILE" ]]; then
    printf 'Missing Azure config: %s\n' "$AZ_ENV_FILE" >&2
    printf 'Copy %s.example to %s and fill in the IDs.\n' \
      "${AZ_ENV_FILE}.example" "$AZ_ENV_FILE" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  source "$AZ_ENV_FILE"
  : "${AZ_TENANT_ID:?AZ_TENANT_ID not set in $AZ_ENV_FILE}"
  : "${AZ_SUBSCRIPTION_ID:?AZ_SUBSCRIPTION_ID not set in $AZ_ENV_FILE}"
}

_az_use() {
  _az_load_ids || return $?
  local login_mode="${1:-browser}"

  if ! command -v az >/dev/null 2>&1; then
    printf '%s\n' "az CLI not found" >&2
    return 127
  fi

  az account set --subscription "$AZ_SUBSCRIPTION_ID" --only-show-errors >/dev/null 2>&1

  if ! az account get-access-token --subscription "$AZ_SUBSCRIPTION_ID" --only-show-errors >/dev/null 2>&1; then
    if [ "$login_mode" = "device" ]; then
      az login --tenant "$AZ_TENANT_ID" --use-device-code --only-show-errors >/dev/null
    else
      az login --tenant "$AZ_TENANT_ID" --only-show-errors >/dev/null
    fi
    az account set --subscription "$AZ_SUBSCRIPTION_ID" --only-show-errors
  fi

  az account show \
    --query "{Name:name, SubscriptionId:id, TenantId:tenantId, IsDefault:isDefault}" \
    --output table
}

# azfit — interactive browser login
azfit() { _az_use browser; }

# azdc — device-code login (for headless / WSL-no-browser sessions)
azdc()  { _az_use device; }

# =========================================================
# Kubernetes context shortcuts
# =========================================================

kcontexts() { kubectl config get-contexts; }
kdev()      { kubectl config use-context aks-astra--dev; kubectl config current-context; }
kmodel()    { kubectl config use-context aks-astra-model; printf 'MODEL context — treat as read-mostly.\n' >&2; kubectl config current-context; }
kprod()     { kubectl config use-context aks-astra-prod;  printf 'PROD context — read-only unless explicitly approved.\n' >&2; kubectl config current-context; }
kcheck()    { kubectl config current-context; kubectl get nodes; }
kns()       { kubectl config set-context --current --namespace="${1:?usage: kns <namespace>}"; }
kcur()      { kubectl config current-context; }
