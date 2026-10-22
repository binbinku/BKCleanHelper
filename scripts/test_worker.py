#!/usr/bin/env python3
"""Lifecycle integration tests. --simulate never installs an event tap."""
import json
import os
import pathlib
import select
import signal
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
binary = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".build/debug/BKCleanHelper"


def launch(duration="2"):
    return subprocess.Popen(
        [str(binary), "--input-worker", "--simulate", "--duration", duration],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0,
    )


def message(process, expected, timeout=3):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        readable, _, _ = select.select([process.stdout], [], [], max(0, end - time.monotonic()))
        if not readable:
            break
        line = process.stdout.readline()
        if not line:
            break
        payload = json.loads(line)
        if payload["kind"] == expected:
            return payload
    raise AssertionError(f"missing {expected}: {process.poll()}")


processes = []
try:
    p = launch("0.4"); processes.append(p)
    message(p, "ready")
    assert message(p, "stopped")["detail"] == "completed"
    assert p.wait(timeout=2) == 0
    print("PASS: independent deadline releases session")

    p = launch(); processes.append(p)
    message(p, "ready")
    p.stdin.write(b"stop\nstop\n"); p.stdin.flush()
    assert message(p, "stopped")["detail"] == "cancelled"
    assert p.wait(timeout=2) == 0
    print("PASS: repeated stop is harmless")

    p = launch(); processes.append(p)
    message(p, "ready")
    p.stdin.close()
    assert message(p, "stopped")["detail"] == "parentExited"
    assert p.wait(timeout=2) == 0
    print("PASS: parent pipe EOF releases session")

    p = launch("0.4"); processes.append(p)
    message(p, "ready")
    os.kill(p.pid, signal.SIGSTOP)
    time.sleep(0.6)
    os.kill(p.pid, signal.SIGCONT)
    assert message(p, "stopped")["detail"] == "completed"
    assert p.wait(timeout=2) == 0
    print("PASS: delayed run loop cannot extend deadline")

    p = launch(); processes.append(p)
    message(p, "ready")
    p.stdout.close()
    assert p.wait(timeout=3) == 4
    print("PASS: broken output pipe exits worker")

    p = launch(); processes.append(p)
    message(p, "ready")
    p.stdin.write(b"x" * 5000); p.stdin.flush()
    assert message(p, "stopped")["detail"] == "invalidCommand"
    assert p.wait(timeout=2) == 0
    print("PASS: malformed input releases session")
finally:
    for p in processes:
        if p.poll() is None:
            p.kill()
        p.wait(timeout=3)
