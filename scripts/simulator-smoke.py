"""Launch the actual compiled app on one iPhone and one iPad simulator. No playback is claimed."""
import json
import pathlib
import re
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "build/simulator/Build/Products/Debug-iphonesimulator/LocalFrame.app"


def run(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()
    except subprocess.CalledProcessError as error:
        print(error.output, flush=True)
        raise


def failed_test_ids(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Case" and node.get("result") == "Failed":
            yield node["nodeIdentifier"]
        yield from failed_test_ids(node.get("children", []))


def export_failure_attachments(bundle, output):
    try:
        results = json.loads(run("xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(bundle)))
        for identifier in failed_test_ids(results.get("testNodes", [])):
            # Teardown screenshots may not be marked as failure-associated by XCTest.
            # Export all attachments for each failed case to retain those diagnostics.
            destination = output / re.sub(r"[^\w.-]", "_", identifier)
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments",
                            "--path", str(bundle), "--test-id", identifier,
                            "--output-path", str(destination)], check=False)
    except (subprocess.CalledProcessError, ValueError, KeyError) as error:
        print(f"Could not export test diagnostics: {error}", flush=True)


inventory = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))
(ROOT / "build/simulator-inventory.log").write_text(json.dumps(inventory, indent=2))
destinations = run("xcodebuild", "-project", "LocalFrame.xcodeproj", "-scheme", "LocalFrame", "-showdestinations")
(ROOT / "build/simulator-destinations.log").write_text(destinations)
supported_ids = set(re.findall(r"platform:iOS Simulator,[^\n]*?\bid:([0-9A-Fa-f-]{36})", destinations))
runtime_names = sorted((name for name in inventory["devices"] if "iOS" in name),
                       key=lambda name: tuple(map(int, re.findall(r"\d+", name.split("iOS-")[-1]))), reverse=True)
# simctl can list devices belonging to runtimes unsupported by the selected Xcode.
devices = [device for runtime in runtime_names for device in inventory["devices"][runtime]
           if device["udid"] in supported_ids]
for family in ("iPhone", "iPad"):
    device = next((device for device in devices if device["name"].startswith(family)), None)
    if device is None:
        raise RuntimeError(f"No {family} simulator is supported by this Xcode; inspect simulator-destinations.log and simulator-inventory.log.")
    identifier = device["udid"]
    print(f"{family}: selected {device['name']} ({identifier})", flush=True)
    booted_here = device["state"] != "Booted"
    try:
        if booted_here:
            run("xcrun", "simctl", "boot", identifier)
        run("xcrun", "simctl", "bootstatus", identifier, "-b")
        if family == "iPhone":
            command = ["xcodebuild", "test", "-project", "LocalFrame.xcodeproj", "-scheme", "LocalFrame",
                       "-configuration", "Debug", "-destination", f"id={identifier}",
                       "-derivedDataPath", "build/simulator", "-parallel-testing-enabled", "NO",
                       "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY="]
            with (ROOT / "build/playback-tests.log").open("w") as log:
                result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=False)
            if result.returncode:
                print((ROOT / "build/playback-tests.log").read_text()[-18000:])
                bundles = sorted((ROOT / "build/simulator/Logs/Test").glob("*.xcresult"),
                                 key=lambda path: path.stat().st_mtime)
                if bundles:
                    export_failure_attachments(bundles[-1], ROOT / "build/ui-test-failures")
                raise RuntimeError("Native playback/library/UI tests failed; inspect playback-tests.log")
            print("Native playback, offline library recovery and UI interaction tests passed.")
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
