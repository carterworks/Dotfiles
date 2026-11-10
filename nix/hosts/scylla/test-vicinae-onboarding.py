import importlib.util
import json
from pathlib import Path
import tempfile


spec = importlib.util.spec_from_file_location(
    "onboarding", Path(__file__).with_name("complete-vicinae-onboarding.py")
)
onboarding = importlib.util.module_from_spec(spec)
spec.loader.exec_module(onboarding)

with tempfile.TemporaryDirectory() as temporary:
    state_home = Path(temporary) / "state"
    onboarding.complete_onboarding(state_home)
    file = state_home / "vicinae/onboarding.json"
    initial = file.read_bytes()
    state = json.loads(initial)
    assert state["version"] == 1
    assert state["completedAt"]
    onboarding.complete_onboarding(state_home)
    assert file.read_bytes() == initial, "Repeated activation must preserve completion state"
    existing = b'{"version": 2, "completedAt": "2026-10-01T00:00:00Z"}'
    file.write_bytes(existing)
    onboarding.complete_onboarding(state_home)
    assert file.read_bytes() == existing, "Do not overwrite newer upstream onboarding state"

print("Vicinae onboarding state checks passed")
