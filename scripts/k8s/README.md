# Socreate Kernel — K8s 加速构建

## 方案概览

| 组件 | 规格 | 用途 |
|------|------|------|
| `kernel-build-job.yaml.template` | 16 CPU / 32Gi | 临时 K8s Job，单次内核编译 |
| `gha-runners.yaml` | 4×4c + 1×16c | 常驻 GitHub Actions self-hosted runner |

内核 spec 是单体 `rpmbuild`，**无法拆成 4 个独立编译 job**；加速靠：
- **`-j16`** 并行 make（16 核机器）
- **`--with baseonly`** 跳过 debug 变体（`KERNEL_BASEONLY=1`）

## 方式 A：临时 K8s Job（推荐）

```bash
# 1. 配置 kubeconfig
export KUBECONFIG=~/.kube/config

# 2. 提交构建（16c / 32G，约 20–40 分钟）
chmod +x scripts/ci/k8s-kernel-build.sh
GIT_REF=main JOBS=16 ./scripts/ci/k8s-kernel-build.sh

# 产物在 RPMS/x86_64/
```

### GitHub Actions 触发

1. 仓库 Settings → Secrets → `KUBECONFIG`（base64 编码的 kubeconfig）
2. workflow_dispatch 勾选 **use_k8s**，或设置仓库变量 `KERNEL_USE_K8S=true`
3. 默认 `kernel_jobs=16`

## 方式 B：Self-hosted Runner（4 + 1）

```bash
# 1. 在 GitHub 生成 runner registration token
# 2. 创建 secret
kubectl apply -f scripts/k8s/namespace.yaml
kubectl -n socreate-build create secret generic gha-runner-token \
  --from-literal=token=YOUR_TOKEN --dry-run=client -o yaml | kubectl apply -f -

# 3. 部署 4 个通用 runner (4c/8G) + 1 个内核专用 runner (16c/32G)
kubectl apply -f scripts/k8s/gha-runners.yaml

# 4. 启用 self-hosted 内核 job
# 仓库 Variables: KERNEL_USE_SELF_HOSTED=true
```

Workflow 会自动调度到带 `16c-32g,kernel` 标签的 runner。

## 资源需求

- 磁盘：≥ 40Gi（内核源码 + 构建树）
- 内存：32Gi 推荐（`-j16` 链接阶段峰值较高）
- CPU：16 核
