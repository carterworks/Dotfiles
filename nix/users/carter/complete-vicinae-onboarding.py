from datetime import datetime, timezone
import json
from pathlib import Path
import sys


def complete_onboarding(state_home):
    directory = Path(state_home) / "vicinae"
    directory.mkdir(parents=True, exist_ok=True)
    try:
        with (directory / "onboarding.json").open("x") as file:
            json.dump({"version": 1, "completedAt": datetime.now(timezone.utc).isoformat()}, file)
    except FileExistsError:
        pass


if __name__ == "__main__":
    complete_onboarding(sys.argv[1])
