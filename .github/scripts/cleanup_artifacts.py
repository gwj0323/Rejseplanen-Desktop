#!/usr/bin/env python3
"""
Automatically cleans up old GitHub Actions artifacts.
- Deletes obsolete legacy artifacts (e.g. rejseplanen-*, rejsenu-*).
- For active artifacts (spor-release-apk, spor-release-ipa), keeps only the newest KEEP_COUNT (default: 1).
"""

import json
import os
import sys
import urllib.error
import urllib.request

TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
REPO = os.environ.get("GITHUB_REPOSITORY", "gwj0323/spor-app")
KEEP_COUNT = int(os.environ.get("KEEP_COUNT", "1"))

if not TOKEN:
    print("Error: GITHUB_TOKEN or GH_TOKEN environment variable is required.")
    sys.exit(1)

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "Artifact-Cleanup-Script",
}


def api_request(url: str, method: str = "GET"):
    req = urllib.request.Request(url, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            if resp.status == 204:
                return None
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.reason} for {url}")
        return None
    except Exception as e:
        print(f"Request failed: {e}")
        return None


def main():
    print(f"Cleaning artifacts for repository: {REPO} (keeping latest {KEEP_COUNT} per artifact name)...")

    # Fetch all artifacts with pagination
    artifacts = []
    page = 1
    while True:
        url = f"https://api.github.com/repos/{REPO}/actions/artifacts?per_page=100&page={page}"
        data = api_request(url)
        if not data or not data.get("artifacts"):
            break
        items = data["artifacts"]
        artifacts.extend(items)
        if len(artifacts) >= data.get("total_count", 0) or len(items) == 0:
            break
        page += 1

    print(f"Total artifacts found: {len(artifacts)}")

    # Group artifacts by name
    by_name = {}
    for a in artifacts:
        name = a["name"]
        by_name.setdefault(name, []).append(a)

    deleted_count = 0
    for name, items in by_name.items():
        # Sort descending by created_at (newest first)
        items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

        # If it's a legacy obsolete artifact name, delete ALL of them
        if name.startswith("rejseplanen-") or name.startswith("rejsenu-"):
            to_delete = items
        else:
            to_delete = items[KEEP_COUNT:]

        for a in to_delete:
            aid = a["id"]
            del_url = f"https://api.github.com/repos/{REPO}/actions/artifacts/{aid}"
            print(f"  Deleting '{name}' (id: {aid}, created: {a.get('created_at')})...")
            api_request(del_url, method="DELETE")
            deleted_count += 1

    print(f"Cleanup finished. Successfully deleted {deleted_count} old artifact(s).")


if __name__ == "__main__":
    main()
