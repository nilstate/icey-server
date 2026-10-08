#!/usr/bin/env python3
"""Read back the public Icey and Icey Server release surfaces."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
LIBRARY_VERSION = (ROOT / "ICEY_VERSION").read_text().strip()
SERVER_VERSION = (ROOT / "VERSION").read_text().strip()
HEADERS = {"User-Agent": "icey-release-audit/1.0"}


def fetch(url):
    try:
        with urlopen(Request(url, headers=HEADERS), timeout=20) as response:
            return response.read().decode(), None
    except HTTPError as error:
        return None, f"HTTP {error.code}"
    except (URLError, TimeoutError) as error:
        return None, str(error)


def version_in(pattern, body):
    match = re.search(pattern, body, re.MULTILINE)
    return match.group(1) if match else None


def check(surface):
    name, owner, expected, url, extract = surface
    body, error = fetch(url)
    if error:
        return dict(name=name, owner=owner, expected=expected, live=None,
                    status="missing" if error == "HTTP 404" else "unknown",
                    url=url, detail=error)
    try:
        live = extract(body)
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        return dict(name=name, owner=owner, expected=expected, live=None,
                    status="unknown", url=url, detail=str(error))
    status = "current" if live == expected else "stale" if live else "missing"
    return dict(name=name, owner=owner, expected=expected, live=live,
                status=status, url=url)


def github_release_version(body):
    return json.loads(body)["tag_name"].removeprefix("v")


def server_assets(body):
    names = {asset["name"] for asset in json.loads(body)["assets"]}
    required = {
        f"icey-server-{SERVER_VERSION}-source.tar.gz",
        f"icey-{LIBRARY_VERSION}-source.tar.gz",
        f"icey-server-{SERVER_VERSION}-Linux-x86_64.tar.gz",
        f"icey-server_{SERVER_VERSION}_amd64.deb",
    }
    return SERVER_VERSION if required <= names else ", ".join(sorted(required - names))


def docker_version(body):
    return json.loads(body)["name"]


def aur_version(package):
    def extract(body):
        matches = [row for row in json.loads(body)["results"] if row["Name"] == package]
        return matches[0]["Version"].split("-", 1)[0] if matches else None
    return extract


def ppa_version(body):
    entries = json.loads(body)["entries"]
    return entries[0]["source_package_version"].split("-", 1)[0] if entries else None


def apt_version(body):
    return version_in(r"^Package: icey-server\nVersion: (\S+)", body)


def crate_version(body):
    return json.loads(body)["crate"]["max_stable_version"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true", help="fail when an owned release surface drifts")
    parser.add_argument("--json", action="store_true", help="print machine-readable results")
    args = parser.parse_args()

    aur = "https://aur.archlinux.org/rpc/v5/info?arg[]=icey&arg[]=icey-server"
    surfaces = [
        ("Icey GitHub release", "owned", LIBRARY_VERSION,
         f"https://api.github.com/repos/nilstate/icey/releases/tags/{LIBRARY_VERSION}", github_release_version),
        ("Icey Server GitHub assets", "owned", SERVER_VERSION,
         f"https://api.github.com/repos/nilstate/icey-server/releases/tags/v{SERVER_VERSION}", server_assets),
        ("Icey Docker", "owned", LIBRARY_VERSION,
         f"https://hub.docker.com/v2/repositories/0state/icey/tags/{LIBRARY_VERSION}", docker_version),
        ("Icey Server Docker", "owned", SERVER_VERSION,
         f"https://hub.docker.com/v2/repositories/0state/icey-server/tags/{SERVER_VERSION}", docker_version),
        ("Icey Homebrew", "owned", LIBRARY_VERSION,
         "https://raw.githubusercontent.com/nilstate/homebrew-tap/main/Formula/icey.rb",
         lambda b: version_in(r'^  version "([^"]+)"', b)),
        ("Icey Server Homebrew", "owned", SERVER_VERSION,
         "https://raw.githubusercontent.com/nilstate/homebrew-tap/main/Formula/icey-server.rb",
         lambda b: version_in(r"/download/v([^/]+)/", b)),
        ("Icey AUR", "owned", LIBRARY_VERSION, aur, aur_version("icey")),
        ("Icey Server AUR", "owned", SERVER_VERSION, aur, aur_version("icey-server")),
        ("Icey Ubuntu PPA", "owned", LIBRARY_VERSION,
         "https://api.launchpad.net/1.0/~0state/+archive/ubuntu/icey?ws.op=getPublishedSources&source_name=icey&exact_match=true&status=Published", ppa_version),
        ("Icey Server APT", "owned", SERVER_VERSION,
         "https://apt.0state.com/icey/dists/stable/main/binary-amd64/Packages", apt_version),
        ("Icey vcpkg", "upstream", LIBRARY_VERSION,
         "https://raw.githubusercontent.com/microsoft/vcpkg/master/ports/icey/vcpkg.json",
         lambda b: json.loads(b)["version"]),
        ("Icey ConanCenter", "upstream", LIBRARY_VERSION,
         "https://raw.githubusercontent.com/conan-io/conan-center-index/master/recipes/icey/config.yml",
         lambda b: version_in(r'^  "([0-9]+\.[0-9]+\.[0-9]+)":', b)),
        ("Icey MacPorts", "upstream", LIBRARY_VERSION,
         "https://raw.githubusercontent.com/macports/macports-ports/master/devel/icey/Portfile",
         lambda b: version_in(r'^github\.setup\s+nilstate\s+icey\s+(\S+)', b)),
        ("Icey Spack", "upstream", LIBRARY_VERSION,
         "https://raw.githubusercontent.com/spack/spack-packages/develop/repos/spack_repo/builtin/packages/icey/package.py",
         lambda b: version_in(r'\bversion\("([0-9]+\.[0-9]+\.[0-9]+)"', b)),
        ("Icey nixpkgs", "upstream", LIBRARY_VERSION,
         "https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/by-name/ic/icey/package.nix",
         lambda b: version_in(r'version\s*=\s*"([^"]+)"', b)),
        ("Icey conda-forge", "upstream", LIBRARY_VERSION,
         "https://api.anaconda.org/package/conda-forge/icey",
         lambda b: json.loads(b)["latest_version"]),
        ("Icey xrepo", "upstream", LIBRARY_VERSION,
         "https://raw.githubusercontent.com/xmake-io/xmake-repo/master/packages/i/icey/xmake.lua",
         lambda b: version_in(r'add_versions\("([^"]+)"', b)),
    ]
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(check, surfaces))

    # Rust bindings have their own version line; expose them without comparing
    # their semver to the C++ library version.
    bindings = []
    for name in ("icey", "icey-sys"):
        url = f"https://crates.io/api/v1/crates/{name}"
        body, error = fetch(url)
        bindings.append(dict(name=f"Rust {name}", owner="bindings",
                             live=crate_version(body) if body else None,
                             status="listed" if body else "unknown", url=url,
                             detail=error))
    results += bindings

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for row in results:
            print(f"{row['status']:8} {row['owner']:8} {row['name']:25} "
                  f"expected={row.get('expected', '-')} live={row.get('live') or '-'}")
    return int(args.strict and any(row["owner"] == "owned" and row["status"] != "current"
                                   for row in results))


if __name__ == "__main__":
    sys.exit(main())
