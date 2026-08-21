dev-browser-windows-x64.exe

Pinned fork: 0.2.9-ergo (ao-kamal/dev-browser, AppVeyor).
NOT SawyerHood npm stock. Requires --channel chrome.

install.ps1 copies this file over the npm package exe and refuses to
finish unless `dev-browser --version` contains "ergo".

Do not run: npm install -g dev-browser@latest
That command replaced this binary on 2026-07-31.
