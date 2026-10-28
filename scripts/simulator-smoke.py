"""Launch the actual compiled app on one iPhone and one iPad simulator. No playback is claimed."""
import json
import pathlib
import re
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "build/simulator/Build/Products/Debug-iphonesimulator/LocalFrame.app"


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()


inventory = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))
runtime_names = sorted((name for name in inventory["devices"] if "iOS" in name),
                       key=lambda name: tuple(map(int, re.findall(r"\d+", name.split("iOS-")[-1]))), reverse=True)
devices = [device for runtime in runtime_names for device in inventory["devices"][runtime]]
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
        if family == "iPhone":
            command = ["xcodebuild", "test", "-workspace", "LocalFrame.xcworkspace", "-scheme", "LocalFrame",
                       "-configuration", "Debug", "-destination", f"id={identifier}",
                       "-derivedDataPath", "build/simulator", "-parallel-testing-enabled", "NO",
                       "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY="]
            with (ROOT / "build/playback-tests.log").open("w") as log:
                result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=False)
            if result.returncode:
                print((ROOT / "build/playback-tests.log").read_text()[-18000:])
                raise RuntimeError("Native playback/first-frame tests failed; inspect playback-tests.log")
            print("Native MP4/MKV first-frame, cancellation, remote-input rejection and playback tests passed.")
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
