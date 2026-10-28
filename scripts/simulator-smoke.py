"""Launch the actual compiled app on one iPhone and one iPad simulator. No playback is claimed."""
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "build/simulator/Build/Products/Debug-iphonesimulator/LocalFrame.app"


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()


inventory = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))
devices = [device for runtime, values in inventory["devices"].items() if "iOS" in runtime for device in values]
for family in ("iPhone", "iPad"):
    device = next((device for device in devices if device["name"].startswith(family)), None)
    if device is None:
        raise RuntimeError(f"No {family} iOS simulator is available on this runner.")
    identifier = device["udid"]
    booted_here = device["state"] != "Booted"
    try:
        if booted_here:
            run("xcrun", "simctl", "boot", identifier)
        run("xcrun", "simctl", "bootstatus", identifier, "-b")
        run("xcrun", "simctl", "install", identifier, str(APP))
        result = run("xcrun", "simctl", "launch", identifier, "com.localframe.player")
        if "com.localframe.player:" not in result:
            raise RuntimeError(result)
        time.sleep(4)
        # A second launch fails to prove liveness, so inspect the existing process instead.
        processes = run("xcrun", "simctl", "spawn", identifier, "launchctl", "list")
        if "com.localframe.player" not in processes:
            raise RuntimeError(f"{family}: app exited after launch")
        run("xcrun", "simctl", "io", identifier, "screenshot", str(ROOT / f"build/{family}-launch.png"))
        print(f"{family}: launched and still running; screenshot saved.")
        run("xcrun", "simctl", "terminate", identifier, "com.localframe.player")
    finally:
        if booted_here:
            subprocess.run(["xcrun", "simctl", "shutdown", identifier], check=False)
