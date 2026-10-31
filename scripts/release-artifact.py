#!/usr/bin/env python3
"""Release selection and integrity-checked extraction for install-ecapture.sh."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tarfile

TAG = re.compile(r"v\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?")


def select_release(release, arch, requested):
    tag = release.get("tag_name", "")
    if not TAG.fullmatch(tag) or release.get("draft"):
        raise ValueError("Invalid tag or draft release")
    if requested != "latest" and tag != requested:
        raise ValueError("Release tag does not match requested version")
    if requested == "latest" and release.get("prerelease"):
        raise ValueError("Latest stable selection returned a prerelease")
    if arch not in {"amd64", "arm64", "loong64"}:
        raise ValueError("Unsupported release architecture")
    assets = release.get("assets", [])

    def asset_url(name):
        matches = [a for a in assets if a.get("name") == name]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one published asset: {name}")
        url = matches[0].get("browser_download_url", "")
        expected = f"https://github.com/gojue/ecapture/releases/download/{tag}/{name}"
        if url != expected:
            raise ValueError(f"Unexpected download URL for {name}")
        return url

    name = f"ecapture-{tag}-linux-{arch}.tar.gz"
    artifact_url = asset_url(name)
    # Loong64 is uploaded by a separate workflow with its own manifest.
    checksum = f"checksum-{tag}.txt"
    arch_checksum = f"checksum-{arch}-{tag}.txt"
    if any(a.get("name") == arch_checksum for a in assets):
        checksum = arch_checksum
    return tag, name, artifact_url, asset_url(checksum)


def verify_extract(archive, manifest, destination):
    archive = Path(archive)
    hashes = []
    for line in Path(manifest).read_text().splitlines():
        fields = line.split(maxsplit=1)
        if len(fields) != 2:
            continue
        filename = fields[1].lstrip("*")
        if PurePosixPath(filename).name == archive.name:
            if not re.fullmatch(r"[0-9a-fA-F]{64}", fields[0]):
                raise ValueError("Invalid SHA256 entry")
            hashes.append(fields[0].lower())
    if len(hashes) != 1:
        raise ValueError(f"Expected exactly one SHA256 entry for {archive.name}")
    digest = hashlib.sha256()
    with archive.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != hashes[0]:
        raise ValueError("SHA256 mismatch; refusing to install")
    with tarfile.open(archive, "r:gz") as bundle:
        candidates = [m for m in bundle.getmembers()
                      if PurePosixPath(m.name).name == "ecapture"]
        if len(candidates) != 1 or not candidates[0].isfile():
            raise ValueError("Archive must contain exactly one regular ecapture binary")
        member = candidates[0]
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError("Unsafe binary member path")
        # Copy only verified binary bytes, never unpack arbitrary archive paths/links.
        with bundle.extractfile(member) as src, Path(destination).open("xb") as dst:
            shutil.copyfileobj(src, dst)
    print("SHA256 verified; extracted ecapture")


def main():
    if len(sys.argv) != 5:
        raise ValueError("Usage: release-artifact.py select JSON ARCH VERSION | verify-extract ARCHIVE CHECKSUM OUTPUT")
    if sys.argv[1] == "select":
        release = json.loads(Path(sys.argv[2]).read_text())
        print("\n".join(select_release(release, sys.argv[3], sys.argv[4])))
    elif sys.argv[1] == "verify-extract":
        verify_extract(*sys.argv[2:])
    else:
        raise ValueError("Unknown operation")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, tarfile.TarError) as exc:
        sys.exit(f"[ERROR] {exc}")
