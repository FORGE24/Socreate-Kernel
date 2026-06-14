#!/usr/bin/bash
# Finalize mirror upload tree: apply script, comps XML, checksums, tarball, UPLOAD guide.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

MIRROR_DEFAULTS="$TOPDIR/SOURCES/socreate-mirror.defaults"
# shellcheck source=/dev/null
[[ -f "$MIRROR_DEFAULTS" ]] && source "$MIRROR_DEFAULTS"

RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
ARCH="${SOCREATE_REPO_ARCH:-x86_64}"
KERNEL_DIRNAME="${SOCREATE_KERNEL_REPO_DIRNAME:-socreate kernel repo}"
STAGE_ROOT="$TOPDIR/dist/mirror-upload/${RELEASEVER}"
TARBALL="$TOPDIR/dist/socreate-${RELEASEVER}-mirror-upload.tar.gz"
COMPS_FILE="$TOPDIR/SOURCES/socreate-comps.xml"

[[ -d "$STAGE_ROOT" ]] || { echo "Missing staging tree: $STAGE_ROOT" >&2; exit 1; }

BASE_STAGE="$STAGE_ROOT/${ARCH}/base-essentials"
if [[ ! -d "$BASE_STAGE" ]] || [[ $(find "$BASE_STAGE" -maxdepth 1 -name '*.rpm' | wc -l) -eq 0 ]]; then
    echo "ERROR: base-essentials missing. Run sync-mirror-base-essentials.sh first." >&2
    exit 1
fi
echo "==> Verify seed packages before packaging"
VERIFY_ONLY=1 bash "$TOPDIR/scripts/ci/sync-mirror-base-essentials.sh"

/bin/cp -f "$TOPDIR/scripts/ci/apply-on-mirror.sh.template" "$STAGE_ROOT/apply-on-mirror.sh"
chmod +x "$STAGE_ROOT/apply-on-mirror.sh"
/bin/cp -f "$COMPS_FILE" "$STAGE_ROOT/socreate-comps.xml"

cat > "$STAGE_ROOT/MANIFEST.sha256" <<EOF
# Socreate mirror upload manifest
# Generated: $(date -Is)
EOF
while IFS= read -r f; do
    sha256sum "$f" >> "$STAGE_ROOT/MANIFEST.sha256"
done < <(find "$STAGE_ROOT" -type f ! -name 'MANIFEST.sha256' | sort)

kernel_rpms="$(find "$STAGE_ROOT/${ARCH}/${KERNEL_DIRNAME}" -maxdepth 1 -name '*.rpm' 2>/dev/null | wc -l)"
overlay_rpms="$(find "$STAGE_ROOT/${ARCH}/overlay" -maxdepth 1 -name '*.rpm' 2>/dev/null | wc -l)"
base_rpms="$(find "$STAGE_ROOT/${ARCH}/base-essentials" -maxdepth 1 -name '*.rpm' 2>/dev/null | wc -l)"

cat > "$STAGE_ROOT/UPLOAD.md" <<EOF
# Socreate 镜像补全包 — 提交说明

生成时间: $(date -Is)

## 交付物

| 文件 | 说明 |
|------|------|
| \`socreate-${RELEASEVER}-mirror-upload.tar.gz\` | 完整上传包（推荐） |
| \`dist/mirror-upload/${RELEASEVER}/\` | 解压后的目录树 |
| \`apply-on-mirror.sh\` | 在镜像服务器上执行的部署脚本 |
| \`MANIFEST.sha256\` | 校验和 |

## 目录结构

\`\`\`
${RELEASEVER}/
├── apply-on-mirror.sh
├── socreate-comps.xml
├── UPLOAD.md
├── MANIFEST.sha256
├── source/                          # SRPM 参考，不进 repodata
└── x86_64/
    ├── socreate kernel repo/        # 内核 + 品牌 (${kernel_rpms} RPM + repodata)
    ├── overlay/                     # Socreate 包 (${overlay_rpms} RPM + repodata/comps)
    └── base-essentials/             # 基础系统补包 (${base_rpms} RPM)
\`\`\`

## 上传步骤

### 方式 A：整包上传（推荐）

1. 将 \`dist/socreate-${RELEASEVER}-mirror-upload.tar.gz\` 传到镜像服务器
2. 解压:
   \`\`\`bash
   tar -xzf socreate-${RELEASEVER}-mirror-upload.tar.gz -C /tmp
   \`\`\`
3. 在镜像服务器执行:
   \`\`\`bash
   cd /tmp/${RELEASEVER}
   bash apply-on-mirror.sh /var/www/html /tmp/${RELEASEVER}
   \`\`\`
   把 \`/var/www/html\` 换成 nginx 实际 docroot。

### 方式 B：手动 rsync

\`\`\`bash
rsync -av /tmp/${RELEASEVER}/x86_64/socreate\\ kernel\\ repo/ \\
  /var/www/html/${RELEASEVER}/${ARCH}/socreate\\ kernel\\ repo/

cp /tmp/${RELEASEVER}/x86_64/overlay/*.rpm /var/www/html/${RELEASEVER}/${ARCH}/
cp /tmp/${RELEASEVER}/x86_64/base-essentials/*.rpm /var/www/html/${RELEASEVER}/${ARCH}/

cd /var/www/html/${RELEASEVER}/${ARCH}
createrepo_c --update --groupfile /tmp/${RELEASEVER}/socreate-comps.xml .
\`\`\`

## 部署后验证

在构建机上:
\`\`\`bash
bash scripts/ci/audit-mirror.sh
\`\`\`

应看到:
- \`kernel\` 仓库含 \`socreate-repos\`、\`kernel-core\`、\`socreate-release\`
- \`base\` 仓库含 \`bash\`、\`glibc\`、\`systemd\`、\`dnf\`、\`socreate-repos\`

## 注意

- **不要**把 \`.src.rpm\` 放进 \`createrepo\` 目录（已在 source/ 单独存放）
- 内核仓库 URL 含空格，必须编码为 \`socreate%20kernel%20repo/\`
- 主仓库仍建议后续做完整 BaseOS/AppStream 同步；本包只补安装必需的最小集合
EOF

echo "==> Create tarball: $TARBALL"
mkdir -p "$TOPDIR/dist"
tar -C "$TOPDIR/dist/mirror-upload" -czf "$TARBALL" "$RELEASEVER"

echo "==> Finalized upload package"
echo "Tarball:  $TARBALL ($(du -h "$TARBALL" | awk '{print $1}'))"
echo "Tree:     $STAGE_ROOT"
echo "Guide:    $STAGE_ROOT/UPLOAD.md"
echo "Checksum: $STAGE_ROOT/MANIFEST.sha256"
echo ""
echo "Kernel RPMs:  ${kernel_rpms}"
echo "Overlay RPMs: ${overlay_rpms}"
echo "Base RPMs:    ${base_rpms}"
