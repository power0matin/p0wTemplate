import os
import re
from pathlib import Path

owner, repo = os.environ["REPOSITORY"].split("/", 1)
is_private = os.environ.get("REPO_PRIVATE", "false").lower() == "true"

preferred = [Path("README.md"), Path("Readme.md"), Path("readme.md")]
readme = next((p for p in preferred if p.exists()), None)
if readme is None:
    candidates = sorted(p for p in Path(".").iterdir() if p.is_file() and p.name.lower().startswith("readme"))
    readme = candidates[0] if candidates else Path("README.md")

text = readme.read_text(encoding="utf-8") if readme.exists() else f"# {repo}\n"

views = (
    f'  <a href="https://hits.sh/github.com/{owner}/{repo}/">'
    f'<img src="https://hits.sh/github.com/{owner}/{repo}.svg?style=flat-square&amp;label=Views&amp;labelColor=18181B&amp;color=0EA5E9&amp;logo=github" alt="Repository Views"/></a>'
)

lines = ["<!-- repo-badges:start -->", '<p align="center">', views]
if is_private:
    lines.append(
        '  <img src="https://img.shields.io/badge/Visibility-Private-8B5CF6?style=flat-square&amp;labelColor=18181B&amp;logo=github&amp;logoColor=white" alt="Private Repository"/>'
    )
else:
    lines.extend([
        f'  <a href="https://github.com/{owner}/{repo}/stargazers"><img src="https://img.shields.io/github/stars/{owner}/{repo}?style=flat-square&amp;label=Stars&amp;labelColor=18181B&amp;color=F59E0B&amp;logo=github&amp;logoColor=white" alt="GitHub Stars"/></a>',
        f'  <a href="https://github.com/{owner}/{repo}/forks"><img src="https://img.shields.io/github/forks/{owner}/{repo}?style=flat-square&amp;label=Forks&amp;labelColor=18181B&amp;color=6366F1&amp;logo=github&amp;logoColor=white" alt="GitHub Forks"/></a>',
        f'  <a href="https://github.com/{owner}/{repo}/issues"><img src="https://img.shields.io/github/issues/{owner}/{repo}?style=flat-square&amp;label=Issues&amp;labelColor=18181B&amp;color=22C55E&amp;logo=github&amp;logoColor=white" alt="GitHub Issues"/></a>',
        f'  <a href="LICENSE"><img src="https://img.shields.io/github/license/{owner}/{repo}?style=flat-square&amp;label=License&amp;labelColor=18181B&amp;color=EF4444&amp;logo=github&amp;logoColor=white" alt="GitHub License"/></a>',
    ])
lines.extend(["</p>", "<!-- repo-badges:end -->"])
block = "\n".join(lines)

marker = re.compile(r"<!-- repo-badges:start -->.*?<!-- repo-badges:end -->", re.S)
if marker.search(text):
    text = marker.sub(block, text, count=1)
else:
    text = re.sub(r"^.*komarev\.com/ghpvc/.*\n?", "", text, flags=re.M)
    html_h1 = re.search(r"</h1>\s*", text, flags=re.I)
    md_h1 = re.search(r"^#\s+.+$", text, flags=re.M)
    pos = html_h1.end() if html_h1 else (md_h1.end() if md_h1 else 0)
    prefix = text[:pos].rstrip()
    suffix = text[pos:].lstrip("\n")
    text = f"{prefix}\n\n{block}\n\n{suffix}" if prefix else f"{block}\n\n{suffix}"

readme.write_text(text.rstrip() + "\n", encoding="utf-8")
