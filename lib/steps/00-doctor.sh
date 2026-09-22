# Check the host can do this, and offer to install what is missing.
step "Checking this host"

MISSING=()
declare -A PKG=( [VBoxManage]=virtualbox [qemu-img]=qemu-utils [xorriso]=xorriso
                 [curl]=curl [ssh]=openssh-client [rsync]=rsync [ssh-keygen]=openssh-client )
for c in VBoxManage qemu-img xorriso curl ssh rsync ssh-keygen; do
  if have "$c"; then ok "$c"; else warn "$c missing"; MISSING+=("${PKG[$c]}"); fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  uniq_pkgs=$(printf '%s\n' "${MISSING[@]}" | sort -u | tr '\n' ' ')
  if have apt-get; then
    say "Installing: $uniq_pkgs"
    sudo apt-get update -qq && sudo apt-get install -y $uniq_pkgs \
      || die "install failed — install these by hand: $uniq_pkgs"
  else
    die "Install these first: $uniq_pkgs"
  fi
fi

# capacity
FREE_GB=$(df -BG --output=avail "$PLP_ROOT" | tail -1 | tr -dc '0-9')
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
[ "${FREE_GB:-0}" -ge 30 ] || warn "only ${FREE_GB}G free here; the base image alone needs ~10G"
[ "${RAM_GB:-0}" -ge 8 ]  || warn "only ${RAM_GB}G RAM; ten candidate VMs want ~20G"
ok "disk ${FREE_GB}G free, RAM ${RAM_GB}G, VirtualBox $(VBoxManage --version 2>/dev/null)"

# Wayland breaks the VirtualBox Qt console. We never open one, but say so.
[ "${XDG_SESSION_TYPE:-}" = wayland ] && \
  warn "Wayland session: VirtualBox GUI keyboards misbehave. This tool never opens a console — everything is ssh."

mkdir -p "$PLP_WORK"
if [ ! -f "$PLP_KEY" ]; then
  say "Generating a dedicated ssh key for these VMs"
  ssh-keygen -t ed25519 -N '' -C "plp-exam" -f "$PLP_KEY" >/dev/null
  ok "$PLP_KEY"
fi
ok "host ready"
