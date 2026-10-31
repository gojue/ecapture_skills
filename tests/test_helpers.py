"""Offline behavior tests for the skill helpers; no eCapture/BPF execution."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
spec = importlib.util.spec_from_file_location("release_artifact", SCRIPTS / "release-artifact.py")
release_artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_artifact)
TAG = "v2.9.1"
BASH = shutil.which("bash")


def release(arch="amd64"):
    names = [f"ecapture-{TAG}-linux-{arch}.tar.gz", f"checksum-{TAG}.txt"]
    if arch == "loong64":
        names.append(f"checksum-loong64-{TAG}.txt")
    return {"tag_name": TAG, "draft": False, "prerelease": False, "assets": [
        {"name": n, "browser_download_url": f"https://github.com/gojue/ecapture/releases/download/{TAG}/{n}"}
        for n in names]}


def make_archive(folder, member="package/ecapture", symlink=False):
    archive = folder / f"ecapture-{TAG}-linux-amd64.tar.gz"
    payload = b'#!/bin/sh\n[ "$1" = --version ] || exit 9\nprintf "fixture eCapture version: v2.9.1\\n"\n'
    with tarfile.open(archive, "w:gz") as bundle:
        info = tarfile.TarInfo(member)
        if symlink:
            info.type = tarfile.SYMTYPE
            info.linkname = "/bin/sh"
            bundle.addfile(info)
        else:
            info.size = len(payload)
            info.mode = 0o755
            bundle.addfile(info, io.BytesIO(payload))
    manifest = folder / f"checksum-{TAG}.txt"
    manifest.write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  bin/" + archive.name + "\n")
    return archive, manifest, payload


class ReleaseTests(unittest.TestCase):
    def test_architectures_and_separate_loong64_checksum(self):
        for arch in ("amd64", "arm64", "loong64"):
            selected = release_artifact.select_release(release(arch), arch, "latest")
            self.assertEqual(selected[1], f"ecapture-{TAG}-linux-{arch}.tar.gz")
            expected = f"checksum-loong64-{TAG}.txt" if arch == "loong64" else f"checksum-{TAG}.txt"
            self.assertTrue(selected[3].endswith("/" + expected))

    def test_missing_asset_manifest_or_wrong_origin_is_rejected(self):
        for mutation in ("asset", "manifest", "origin", "duplicate"):
            data = release()
            if mutation == "asset":
                data["assets"].pop(0)
            elif mutation == "manifest":
                data["assets"].pop()
            elif mutation == "origin":
                data["assets"][0]["browser_download_url"] = "https://example.com/binary"
            else:
                data["assets"].append(data["assets"][0])
            with self.assertRaises(ValueError, msg=mutation):
                release_artifact.select_release(data, "amd64", "latest")

    def test_wrong_version_and_unrequested_prerelease(self):
        with self.assertRaises(ValueError):
            release_artifact.select_release(release(), "amd64", "v2.8.0")
        data = release()
        data["prerelease"] = True
        with self.assertRaises(ValueError):
            release_artifact.select_release(data, "amd64", "latest")

    def test_verified_binary_extraction(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            archive, manifest, payload = make_archive(folder)
            output = folder / "binary"
            with contextlib.redirect_stdout(io.StringIO()):
                release_artifact.verify_extract(archive, manifest, output)
            self.assertEqual(output.read_bytes(), payload)
            self.assertFalse((folder / "package").exists())

    def test_bad_or_missing_checksum_never_creates_binary(self):
        for kind in ("mismatch", "missing", "duplicate", "malformed"):
            with tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                archive, manifest, _ = make_archive(folder)
                if kind == "mismatch":
                    manifest.write_text("0" * 64 + "  " + archive.name + "\n")
                elif kind == "missing":
                    manifest.write_text("0" * 64 + "  another-file.tar.gz\n")
                elif kind == "duplicate":
                    manifest.write_text(manifest.read_text() * 2)
                else:
                    manifest.write_text("not-a-hash  " + archive.name + "\n")
                output = folder / "binary"
                with self.assertRaises(ValueError, msg=kind):
                    release_artifact.verify_extract(archive, manifest, output)
                self.assertFalse(output.exists())

    def test_unsafe_binary_members_rejected(self):
        for member, symlink in (("../ecapture", False), ("/ecapture", False), ("p/ecapture", True)):
            with tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                archive, manifest, _ = make_archive(folder, member, symlink)
                output = folder / "binary"
                with self.assertRaises(ValueError):
                    release_artifact.verify_extract(archive, manifest, output)
                self.assertFalse(output.exists())


class ShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.bin = self.folder / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        MOCK_OS="Linux", MOCK_ARCH="x86_64", MOCK_KERNEL="6.6.0", MOCK_UID="0",
                        FIXTURES=str(self.folder), PYTHONDONTWRITEBYTECODE="1")
        self.env.pop("ANDROID_ROOT", None)
        self.mock("uname", 'case "$1" in -s) echo "$MOCK_OS";; -m) echo "$MOCK_ARCH";; -r) echo "$MOCK_KERNEL";; esac\n')
        self.mock("id", 'echo "$MOCK_UID"\n')
        self.mock("ecapture", 'printf "fixture eCapture version: v2.9.1\\n"\n')
        self.mock("getcap", 'exit 0\n')

    def mock(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def run_script(self, script, *args):
        return subprocess.run([BASH, str(SCRIPTS / script), *args], env=self.env,
                              text=True, capture_output=True, timeout=15)

    def test_minimum_kernel_boundaries(self):
        for arch, minimum, below in (("x86_64", "4.18.0", "4.17.9"),
                                     ("aarch64", "5.5.0", "5.4.99"),
                                     ("loongarch64", "6.6.0", "6.5.99")):
            self.env.update(MOCK_ARCH=arch, MOCK_KERNEL=below)
            self.assertEqual(self.run_script("preflight-check.sh").returncode, 1)
            self.env["MOCK_KERNEL"] = minimum
            result = self.run_script("preflight-check.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
        self.env.update(MOCK_ARCH="x86_64", MOCK_KERNEL="7.0.0-custom")
        self.assertEqual(self.run_script("preflight-check.sh").returncode, 0)

    def test_unsupported_host_and_nonroot_capability_path(self):
        for os_name in ("Darwin", "FreeBSD"):
            self.env["MOCK_OS"] = os_name
            self.assertEqual(self.run_script("preflight-check.sh").returncode, 1)
            self.assertEqual(self.run_script("install-ecapture.sh", "--dry-run").returncode, 1)
            self.assertEqual(self.run_script("detect-libs.sh").returncode, 1)
        self.env.update(MOCK_OS="Linux", MOCK_ARCH="riscv64")
        self.assertEqual(self.run_script("preflight-check.sh").returncode, 1)
        self.env.update(MOCK_ARCH="x86_64", MOCK_UID="1000")
        self.assertEqual(self.run_script("preflight-check.sh").returncode, 2)

    def test_missing_binary_fails_preflight(self):
        (self.bin / "ecapture").unlink()
        # Deliberately exclude the host PATH so an installed ecapture cannot leak in.
        self.env["PATH"] = str(self.bin)
        self.mock("dirname", 'printf "%s\\n" "${1%/*}"\n')
        self.assertEqual(self.run_script("preflight-check.sh").returncode, 1)

    def setup_downloads(self, arch="amd64"):
        (self.folder / "release.json").write_text(json.dumps(release(arch)))
        archive, manifest, payload = make_archive(self.folder)
        downloader = self.bin / "curl"
        downloader.write_text(f"#!{sys.executable}\n" + '''import os, pathlib, shutil, sys
args = sys.argv[1:]
out = pathlib.Path(args[args.index("--output") + 1])
url = args[-1]
root = pathlib.Path(os.environ["FIXTURES"])
with (root / "requests").open("a") as log:
    log.write(url + "\\n")
source = root / ("release.json" if "api.github.com" in url else url.rsplit("/", 1)[1])
shutil.copyfile(source, out)
''')
        downloader.chmod(0o755)
        return archive, manifest, payload

    def test_dry_run_nonroot_fetches_metadata_only_for_each_arch(self):
        for arch, machine in (("amd64", "x86_64"), ("arm64", "aarch64"), ("loong64", "loongarch64")):
            self.setup_downloads(arch)
            requests = self.folder / "requests"
            requests.unlink(missing_ok=True)
            self.env.update(MOCK_ARCH=machine, MOCK_UID="1000")
            destination = self.folder / "unused"
            result = self.run_script("install-ecapture.sh", "--dry-run", "--install-dir", str(destination))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(requests.read_text().splitlines()), 1)
            self.assertFalse(destination.exists())
            self.assertIn(f"linux-{arch}.tar.gz", result.stdout)
            self.assertNotIn("-nocore.tar.gz", result.stdout)

    def test_installation_and_checksum_failure_preserves_existing_binary(self):
        _, manifest, payload = self.setup_downloads()
        destination = self.folder / "installed"
        self.env["MOCK_UID"] = "1000"
        result = self.run_script("install-ecapture.sh", TAG, "--install-dir", str(destination))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((destination / "ecapture").read_bytes(), payload)
        old_binary = b"previous installation"
        (destination / "ecapture").write_bytes(old_binary)
        manifest.write_text("0" * 64 + f"  ecapture-{TAG}-linux-amd64.tar.gz\n")
        result = self.run_script("install-ecapture.sh", TAG, "--install-dir", str(destination))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((destination / "ecapture").read_bytes(), old_binary)

    def test_android_installer_is_rejected(self):
        self.env["ANDROID_ROOT"] = "/system"
        self.assertEqual(self.run_script("install-ecapture.sh", "--dry-run").returncode, 1)

    def test_library_discovery_uses_all_candidates_without_executing_them(self):
        self.mock("ldconfig", 'printf "libssl.so.3 => /lib/libssl.so.3\\nlibssl.so.1.1 => /lib/libssl.so.1.1\\nlibgnutls.so.30 => /lib/libgnutls.so.30\\n"\n')
        result = self.run_script("detect-libs.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--libssl=/lib/libssl.so.3", result.stdout)
        self.assertIn("--libssl=/lib/libssl.so.1.1", result.stdout)
        self.assertIn("--gnutls=/lib/libgnutls.so.30", result.stdout)
        self.assertEqual(self.run_script("detect-libs.sh", "--pid", "bad").returncode, 1)


if __name__ == "__main__":
    unittest.main()
