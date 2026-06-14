#!/usr/bin/bash
# Submit ephemeral K8s kernel build (16c / 32G) and collect RPM artifacts.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
NAMESPACE="${K8S_NAMESPACE:-socreate-build}"
JOB_NAME="${K8S_JOB_NAME:-socreate-kernel-build}"
TEMPLATE="${K8S_MANIFEST:-$TOPDIR/scripts/k8s/kernel-build-job.yaml.template}"
WAIT_TIMEOUT="${K8S_WAIT_TIMEOUT:-3h}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$TOPDIR/RPMS/x86_64}"

GIT_REPO="${GIT_REPO:-https://github.com/FORGE24/Socreate-Kernel.git}"
GIT_REF="${GIT_REF:-main}"
FEDORA_VERSION="${FEDORA_VERSION:-44}"
KERNEL_NEVR="${KERNEL_NEVR:-7.0.12-201.fc44}"
SOCREATE_DIST="${SOCREATE_DIST:-.soc26h1q2}"
JOBS="${JOBS:-16}"
KERNEL_BASEONLY="${KERNEL_BASEONLY:-0}"

if [[ -z "${KUBECONFIG:-}" ]]; then
    echo "KUBECONFIG is not set"
    exit 1
fi

export GIT_REPO GIT_REF FEDORA_VERSION KERNEL_NEVR SOCREATE_DIST JOBS KERNEL_BASEONLY

echo "==> Ensure namespace ${NAMESPACE}"
kubectl apply -f "$TOPDIR/scripts/k8s/namespace.yaml"

echo "==> Delete previous job (if any)"
kubectl -n "${NAMESPACE}" delete job "${JOB_NAME}" --ignore-not-found=true
kubectl -n "${NAMESPACE}" wait --for=delete "job/${JOB_NAME}" --timeout=120s 2>/dev/null || true

echo "==> Submit kernel build job (${JOBS} parallel make jobs, 16 CPU / 32Gi)"
envsubst < "${TEMPLATE}" | kubectl apply -f -

echo "==> Wait for job completion (timeout: ${WAIT_TIMEOUT})"
kubectl -n "${NAMESPACE}" wait --for=condition=complete "job/${JOB_NAME}" --timeout="${WAIT_TIMEOUT}"

POD="$(kubectl -n "${NAMESPACE}" get pods -l job-name="${JOB_NAME}" -o jsonpath='{.items[0].metadata.name}')"
echo "==> Build pod: ${POD}"

mkdir -p "${ARTIFACT_DIR}"
tmpdir="$(mktemp -d)"
echo "==> Copy kernel RPM artifacts to ${ARTIFACT_DIR}"
kubectl -n "${NAMESPACE}" cp "${POD}:/build/RPMS/x86_64/." "${tmpdir}/"
chmod +x "${TOPDIR}/scripts/ci/import-kernel-rpms.sh"
KERNEL_IMPORT_DIR="${tmpdir}" ARTIFACT_DIR="${ARTIFACT_DIR}" "${TOPDIR}/scripts/ci/import-kernel-rpms.sh"
rm -rf "${tmpdir}"

echo "==> Kernel RPMs:"
ls -lh "${ARTIFACT_DIR}/"*.rpm 2>/dev/null || ls -lh "${ARTIFACT_DIR}/"

echo "==> Pod logs (tail):"
kubectl -n "${NAMESPACE}" logs "${POD}" --tail=80
