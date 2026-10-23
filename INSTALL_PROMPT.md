Install and verify **M5Vitals** — a minimal macOS desktop widget that shows CPU/GPU temperature — on this Mac.

Context you need:
- Repo: https://github.com/qinchuqiaox-creator/M5Vitals (MIT licence)
- M5Vitals itself contains **no sensor code**. Temperatures/power come from macmon (MIT, https://github.com/vladkens/macmon), which it polls over local HTTP.
- Target: Apple Silicon Mac (M1–M5), macOS 13+. No `sudo` is needed at any step.

Do these steps in order and report the real output of each command:

1. Confirm the machine qualifies: `uname -m` must be `arm64`, `sw_vers -productVersion` must be >= 13. If not, stop and tell me.

2. Confirm Homebrew exists (`/opt/homebrew/bin/brew` or `brew` on PATH). If it is missing, stop and ask me to install it from https://brew.sh — do not install Homebrew silently.

3. Install and start the sensor backend:
   `brew install macmon`
   `macmon serve --install --host 127.0.0.1 --port 41414`
   Then prove it works: `curl -s http://127.0.0.1:41414/json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["temp"], d["sys_power"])'` — real numbers, not null (do not assume `jq` exists; stock macOS has no jq). If port 41414 is already served by an existing macmon, reuse it and skip the install.

4. Confirm the Swift toolchain: `xcode-select -p`. If missing, run `xcode-select --install` and wait for it to finish (it opens a GUI dialog).

5. Clone and build:
   `git clone https://github.com/qinchuqiaox-creator/M5Vitals.git ~/src/M5Vitals`
   `cd ~/src/M5Vitals && ./build.sh`
   The script must end with `built: /Users/<you>/Applications/M5Vitals.app`. If `swiftc` fails, show me the error verbatim.

6. Launch: `open ~/Applications/M5Vitals.app`

7. Verify — do not assume, check:
   - `pgrep -fl M5Vitals.app` shows the process;
   - a window named `M5Vitals` exists at window level `-1` (desktop layer) — a 15-line Swift script using `CGWindowListCopyWindowInfo` is enough;
   - the card's numbers match reality: compare what is on screen (screenshot the card region and OCR it) with `curl -s http://127.0.0.1:41414/json`. CPU/GPU temperature must agree within ~2 °C.
   - expected card content: `CPU <util>% <temp>°`, `GPU <util>% <temp>°`, `RAM <used>/<total> GB`, `<watts> W`.

8. Ask me whether it should start at login. Only if I say yes:
   `sed "s|\$HOME|$HOME|g" ~/src/M5Vitals/launchagent/dev.example.m5vitals.plist > ~/Library/LaunchAgents/dev.example.m5vitals.plist`
   `launchctl load ~/Library/LaunchAgents/dev.example.m5vitals.plist`

9. Finally tell me: where the card sits on screen, the CPU/GPU temperatures it is showing right now, and that I can drag it anywhere, hide it via the menu-bar 🌡 item (Show / Hide), or pin it above all windows (Float on Top).

Rules:
- Never use `sudo`; if a step asks for a password, stop and ask me.
- Touch nothing outside `~/src/M5Vitals`, `~/Applications`, `~/Library/LaunchAgents`.
- Do not move my mouse or steal focus while I am using the machine; verify with scripts, not by clicking around.
- Report actual command output. If a step fails, show me the error instead of inventing a result.
