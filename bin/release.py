#!/usr/bin/env python3
import datetime
import os
import re
import subprocess
import sys

# Try to import rich, fallback to basic output if not available
try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.prompt import Confirm, Prompt
    HAS_RICH = True
except ImportError:
    HAS_RICH = False

def should_use_color():
    if os.environ.get('NO_COLOR'): return False
    if os.environ.get('FORCE_COLOR'): return True
    if os.environ.get('TERM') == 'dumb': return False
    return sys.stderr.isatty()

_USE_COLOR = should_use_color()

class Colors:
    RESET = '\033[0m' if _USE_COLOR else ''
    RED = '\033[31m' if _USE_COLOR else ''
    GREEN = '\033[32m' if _USE_COLOR else ''
    YELLOW = '\033[33m' if _USE_COLOR else ''
    CYAN = '\033[36m' if _USE_COLOR else ''
    LIGHTBLACK = '\033[90m' if _USE_COLOR else ''

def print_f(message, color=None, show_time=True):
    color_map = {
        'red': Colors.RED,
        'green': Colors.GREEN,
        'yellow': Colors.YELLOW,
        'cyan': Colors.CYAN,
        'normal': Colors.RESET,
    }
    prefix = ''
    if show_time:
        now = datetime.datetime.now().strftime('%H:%M:%S')
        prefix += f"{Colors.LIGHTBLACK}{now}{Colors.RESET} "
        if color in ['green', 'cyan']: prefix += f"{Colors.GREEN}INF{Colors.RESET} "
        elif color == 'yellow': prefix += f"{Colors.YELLOW}WRN{Colors.RESET} "
        elif color == 'red': prefix += f"{Colors.RED}ERR{Colors.RESET} "

    color_code = color_map.get(color, '')
    print(f"{prefix}{color_code}{message}{Colors.RESET}")

def run_cmd(cmd, capture_output=False, check=True):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=capture_output, text=True, check=check)
        return result.stdout.strip() if capture_output else None
    except subprocess.CalledProcessError as e:
        print_f(f"Command failed: {cmd}", 'red')
        return None

def get_current_branch():
    return run_cmd('git rev-parse --abbrev-ref HEAD', capture_output=True)

def is_behind_origin():
    run_cmd('git fetch origin', capture_output=False, check=False)
    branch = get_current_branch()
    if not branch: return False, 0
    result = run_cmd(f'git rev-list --count HEAD..origin/{branch}', capture_output=True, check=False)
    if result:
        return int(result) > 0, int(result)
    return False, 0



def parse_tag(tag):
    """Parse tag following X.Y.Z-N pattern"""
    match = re.match(r'^(\d+\.\d+\.\d+)-(\d+)$', tag)
    if match:
        version_parts = tuple(map(int, match.group(1).split('.')))
        revision = int(match.group(2))
        return version_parts, revision
    return None

def get_latest_tag():
    """Get the latest tag matching the revision pattern"""
    tags_raw = run_cmd('git tag --list', capture_output=True)
    if not tags_raw: return None

    parsed_tags = []
    for tag in tags_raw.split('\n'):
        tag = tag.strip()
        parsed = parse_tag(tag)
        if parsed:
            parsed_tags.append((parsed, tag))

    if not parsed_tags: return None

    # Sort by version tuple then revision int
    parsed_tags.sort(key=lambda x: x[0], reverse=True)
    return parsed_tags[0][1]

def main():
    if HAS_RICH:
        console = Console()

    print_f("Starting release process for Secure CDN...", 'cyan')

    # Check branch
    branch = get_current_branch()
    if branch != 'main':
        msg = f"You are on branch '{branch}' instead of 'main'."
        if HAS_RICH:
            console.print(Panel.fit(f"[yellow]⚠️  {msg}[/yellow]", title="Branch Check", border_style="yellow"))
            if not Confirm.ask("Proceed anyway?", default=False): sys.exit(1)
        else:
            print_f(f"WARNING: {msg}", 'yellow')
            if input("Proceed anyway? (y/N): ").lower() != 'y': sys.exit(1)

    # Sync check
    print_f("Checking sync with origin...", 'cyan')
    is_behind, count = is_behind_origin()
    if is_behind:
        msg = f"Your local branch is {count} commit(s) behind origin."
        if HAS_RICH:
            console.print(Panel.fit(f"[yellow]⚠️  {msg}[/yellow]", title="Sync Check", border_style="yellow"))
            if not Confirm.ask("Proceed without pulling?", default=False): sys.exit(1)
        else:
            print_f(f"WARNING: {msg}", 'yellow')
            if input("Proceed anyway? (y/N): ").lower() != 'y': sys.exit(1)

    # Dirty check
    if run_cmd('git status --porcelain', capture_output=True):
        print_f("Repository is dirty. Please commit or stash changes.", 'red')
        if '--force' not in sys.argv: sys.exit(1)
        print_f("Continuing with --force...", 'yellow')

    # Versioning
    latest_tag = get_latest_tag()

    if latest_tag:
        print_f(f"Latest tag found: {latest_tag}", 'cyan')
        lt_version_parts, lt_revision = parse_tag(latest_tag)
        lt_version_str = ".".join(map(str, lt_version_parts))
        new_tag = f"{lt_version_str}-{lt_revision + 1}"
    else:
        new_tag = "1.0.0-1"
        print_f("No valid revision tags (X.Y.Z-N) found. Starting at 1.0.0-1", 'yellow')

    if HAS_RICH:
        console.print(Panel.fit(f"[bold cyan]Proposed new tag: {new_tag}[/bold cyan]", title="Next Release", border_style="cyan"))
        if not Confirm.ask("Is this correct?", default=True):
            new_tag = Prompt.ask("Enter manual tag (X.Y.Z-N)")
    else:
        print_f(f"Proposed tag: {new_tag}", 'cyan')
        if input("Is this correct? (Y/n): ").lower() == 'n':
            new_tag = input("Enter manual tag: ")

    # GitHub Auth
    if run_cmd('gh auth status', check=False) != 0:
        print_f("Please login to GitHub CLI: gh auth login", 'red')
        sys.exit(1)

    # Create Tag
    print_f(f"Creating tag {new_tag}...", 'cyan')
    run_cmd(f'git tag {new_tag}')
    run_cmd(f'git push origin {new_tag}')

    # Create Release
    if HAS_RICH:
        if Confirm.ask(f"Create GitHub release for {new_tag}?", default=True):
            run_cmd(f'gh release create {new_tag}')
            print_f("Release created!", 'green')
    else:
        if input(f"Create GitHub release for {new_tag}? (Y/n): ").lower() != 'n':
            run_cmd(f'gh release create {new_tag}')
            print_f("Release created!", 'green')

    print_f("Process complete.", 'green')

if __name__ == "__main__":
    main()
