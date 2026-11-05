"""Run the real-task benchmark in fresh read-only Claude Code sessions and report routing and reading cost.

python tools/slugs/eval_skill_routing.py --label after [--tree <folder>] [--task id] [--model sonnet]
Each session plans only: it may read and search but not edit. It uses account usage, so run it when instructions change.
Compare two labels with --compare before after. Fewer files read is only better if routing stays right, and this does
not measure whether the resulting work is any good.
"""
import argparse
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TASKS = ROOT / "tests/skill-evals/tasks.json"
OUT = ROOT / "build/skill-evals"
SUFFIX = ("\n\nThis is a planning check. Do not edit anything or run commands. Load whatever instructions or skills you "
          "would normally use, read only what you would need, then state in under 100 words which skill leads this work and your first step.")


def run_task(task, tree, model):
    command = ["claude", "-p", task["prompt"] + SUFFIX, "--output-format", "stream-json", "--verbose", "--model", model,
               "--allowedTools", "Read,Grep,Glob,Skill", "--disallowedTools", "Edit,Write,Bash,PowerShell,Agent"]
    done = subprocess.run(command, cwd=tree, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=420)
    skills, reads, greps, cost, turns, text = [], [], 0, None, None, ""
    for line in done.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "assistant":
            for part in event["message"].get("content", []):
                if part.get("type") == "tool_use":
                    if part["name"] == "Skill":
                        skills.append(part["input"].get("skill", ""))
                    elif part["name"] == "Read":
                        reads.append(part["input"].get("file_path", ""))
                    elif part["name"] in ("Grep", "Glob"):
                        greps += 1
        elif event.get("type") == "result":
            cost, turns, text = event.get("total_cost_usd"), event.get("num_turns"), event.get("result", "")
    bytes_read = 0
    for path in reads:
        try:
            bytes_read += Path(path).stat().st_size
        except OSError:
            pass
    mentioned = [name for name in task["expect"] + task["reject"] if name in text]
    routed = set(skills) | set(mentioned)
    right = (not task["expect"] or bool(routed & set(task["expect"]))) and not (set(skills) & set(task["reject"]))
    return {"id": task["id"], "right": right, "skills": skills, "mentioned": mentioned, "files": len(reads), "bytes": bytes_read,
            "searches": greps, "turns": turns, "cost": cost, "answer": text.strip()[:600], "reads": [Path(p).name for p in reads]}


def compare(names):
    rows = {name: {r["id"]: r for r in json.loads((OUT / f"{name}.json").read_text(encoding="utf-8"))} for name in names}
    a, b = names
    print(f"{'task':28} {a+' right':>10} {b+' right':>10} {a+' KB':>9} {b+' KB':>9} {a+' reads':>9} {b+' reads':>9}")
    for task in rows[a]:
        x, y = rows[a][task], rows[b].get(task, {})
        print(f"{task:28} {str(x['right']):>10} {str(y.get('right')):>10} {x['bytes']//1024:>9} {y.get('bytes',0)//1024:>9} {x['files']:>9} {y.get('files',0):>9}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label")
    parser.add_argument("--tree", default=str(ROOT))
    parser.add_argument("--task")
    parser.add_argument("--model", default="sonnet")
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--compare", nargs=2)
    args = parser.parse_args()
    if args.compare:
        compare(args.compare)
        return
    tasks = [t for t in json.loads(TASKS.read_text(encoding="utf-8"))["tasks"] if not args.task or t["id"] == args.task]
    with ThreadPoolExecutor(args.workers) as pool:
        results = list(pool.map(lambda t: run_task(t, args.tree, args.model), tasks))
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{args.label}.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    for r in results:
        print(r["id"], "RIGHT" if r["right"] else "WRONG", r["skills"], r["files"], "files", r["bytes"] // 1024, "KB", r["cost"])


if __name__ == "__main__":
    main()
