# Fetch the Ubuntu cloud image and build the cloud-init seed.
# No installer, no ISO remastering, no keystrokes.
step "Preparing the base image"

IMG_NAME="ubuntu-${UBUNTU_RELEASE}-server-cloudimg-amd64.img"
IMG_URL="https://cloud-images.ubuntu.com/releases/${UBUNTU_RELEASE}/release/${IMG_NAME}"
IMG="$PLP_WORK/$IMG_NAME"
VDI="$PLP_WORK/${VM_NAME}.vdi"
SEED="$PLP_WORK/seed.iso"

if [ ! -f "$IMG" ]; then
  say "Downloading $IMG_NAME (~600 MB, once)"
  curl -fL --progress-bar -o "$IMG.part" "$IMG_URL" || die "download failed: $IMG_URL"
  mv "$IMG.part" "$IMG"
fi
ok "cloud image: $(du -h "$IMG" | cut -f1)"

if [ ! -f "$VDI" ]; then
  say "Converting to VDI and resizing to ${DISK_MB}MB"
  qemu-img convert -f qcow2 -O vdi "$IMG" "$VDI" || die "qemu-img convert failed"
  VBoxManage modifymedium disk "$VDI" --resize "$DISK_MB" >/dev/null \
    || warn "resize failed; cloud-init will still boot but the disk stays small"
fi
ok "disk: $VDI"

# --- cloud-init seed ---------------------------------------------------------
ADMIN_PW_FILE="$PLP_WORK/admin-password"
[ -f "$ADMIN_PW_FILE" ] || { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 > "$ADMIN_PW_FILE"; }
ADMIN_PW=$(cat "$ADMIN_PW_FILE")
PUBKEY=$(cat "$PLP_KEY.pub")

SEEDDIR="$PLP_WORK/seed"; rm -rf "$SEEDDIR"; mkdir -p "$SEEDDIR"
cat > "$SEEDDIR/meta-data" <<META
instance-id: plp-exam-$(date +%s)
local-hostname: plp-exam
META
cat > "$SEEDDIR/user-data" <<USERDATA
#cloud-config
hostname: plp-exam
manage_etc_hosts: false
users:
  - name: ${ADMIN_USER}
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
    ssh_authorized_keys:
      - ${PUBKEY}
ssh_pwauth: true
chpasswd:
  expire: false
  users:
    - name: ${ADMIN_USER}
      password: ${ADMIN_PW}
      type: text
growpart:
  mode: auto
  devices: ['/']
resize_rootfs: true
package_update: true
packages: [openssh-server, rsync]
runcmd:
  - [ systemctl, enable, --now, ssh ]
  - [ touch, /var/lib/cloud/plp-ready ]
USERDATA

xorriso -as mkisofs -quiet -output "$SEED" -volid CIDATA -joliet -rock \
        "$SEEDDIR/user-data" "$SEEDDIR/meta-data" || die "seed ISO build failed"
ok "seed: $SEED  (admin '$ADMIN_USER', password in $ADMIN_PW_FILE)"
