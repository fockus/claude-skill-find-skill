import os
import sys
from pathlib import Path


def main() -> None:
    data_dir = Path(__file__).parent / "data"

    cmd = sys.argv[1] if len(sys.argv) > 1 else ""

    if cmd == "version":
        from find_skill_cli import __version__
        print(f"find-skill {__version__}")
        return

    if cmd == "update":
        script = data_dir / "update-skills-catalogue.sh"
        _exec_sh(script, sys.argv[2:])

    if cmd == "uninstall":
        script = data_dir / "uninstall.sh"
        _exec_sh(script, sys.argv[2:])

    # Default: install
    _exec_sh(data_dir / "install.sh", sys.argv[1:])


def _exec_sh(script: Path, args: list[str]) -> None:
    if not script.exists():
        print(f"Error: bundled script not found: {script}", file=sys.stderr)
        sys.exit(1)

    # Ensure all bundled .sh files are executable on first run
    for sh in script.parent.rglob("*.sh"):
        sh.chmod(sh.stat().st_mode | 0o111)
    script.chmod(script.stat().st_mode | 0o111)

    os.execv("/bin/bash", ["/bin/bash", str(script)] + args)
