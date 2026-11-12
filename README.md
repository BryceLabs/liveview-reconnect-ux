# LiveView reconnect UX demo

Come back to a Phoenix LiveView tab that has been in the background for a while
and you are often greeted by a red "Something went wrong! Attempting to
reconnect" toast. Usually nothing is wrong: the connection dropped while the tab
was hidden, and it reconnects a few hundred milliseconds after you return.

This app lets you compare stock LiveView with a patched client, side by side,
on the same server.

## What the patch changes

The change lives on the [`reconnect-ux` branch of the BryceLabs fork](https://github.com/BryceLabs/phoenix_live_view/compare/main...BryceLabs:phoenix_live_view:reconnect-ux)
and is meant as an upstream pull request to `phoenixframework/phoenix_live_view`.

1. **No disconnected UI while the page is hidden.** `phx-disconnected`
   commands used to run 500ms after the drop, whether or not anyone could see
   the page. phoenix.js does not reconnect a hidden page, so the toast was
   always already up when you came back. Now they wait until the page is
   visible, then give the immediate reconnect `disconnectedResumeTimeout`
   (2000ms by default) to finish. If it does, you see nothing. The
   `phx-loading`/`phx-error` classes are still applied right away, so the
   generated top bar still gives a subtle hint.
2. **Join timeouts are client errors.** A join that timed out or failed in the
   transport set `phx-server-error`, so the generated layout said "Something
   went wrong!" when the server simply could not be reached. It now sets
   `phx-client-error` ("We can't find the internet"), matching the network
   attribution LiveView already uses for its diagnostics.

Nothing changes for a tab you are looking at: drops still show the toast after
500ms if the socket has not come back.

## Try it

You need Elixir 1.15+ and Erlang/OTP 26+.

```sh
git clone https://github.com/BryceLabs/liveview-reconnect-ux.git
cd liveview-reconnect-ux
mix setup
mix phx.server
```

Open <http://localhost:4000>, then:

1. Pick the **Patched** or **Stock** client at the top of the page
   (`?client=patched` or `?client=stock`). The server is the same for both.
2. Start a scenario and switch to another tab within 5 seconds.
3. Wait a few seconds, come back, and watch the top right corner. The
   timeline at the bottom of the page records when each toast appeared,
   measured from when you returned.

What to expect, measured in headless Chromium with an emulated hidden tab
(times from when the tab became visible again):

| Scenario | Stock | Patched |
|---|---|---|
| Blip while away | Red toast already up | No toast |
| Outage while away (20s) | Toast already up | No toast at +1.5s, toast at +2.0s |
| Slow rejoin (join timeout) | "Something went wrong!" at +10.5s | "We can't find the internet" at +2.0s |
| Drop while watching | No toast (fast reconnect) | Unchanged |

## Use the fork in your own app

Point the dependency at the `reconnect-ux-build` branch, which is
`reconnect-ux` plus the built JS in `priv/static` that a git dependency needs:

```elixir
{:phoenix_live_view,
 github: "BryceLabs/phoenix_live_view", branch: "reconnect-ux-build", override: true}
```

The fork tracks LiveView `main` (1.3.0-dev), so expect the usual differences
from the 1.2 release. The draft upstream pull request description is in
[`docs/UPSTREAM_PR.md`](docs/UPSTREAM_PR.md).

## How the scenarios work

- `ReconnectDemo.Chaos` holds global switches for every connected tab.
- Dropping a connection kills the LiveView's WebSocket transport process, so
  the browser sees an unclean close, as when Wi-Fi drops or a laptop sleeps.
- During an outage, `ReconnectDemoWeb.LiveSocket` refuses new connections.
- Slow rejoin makes connected mounts sleep for 12s, past phoenix.js's 10s
  join timeout.
- `assets/vendor/phoenix_live_view_stock.esm.js` is upstream `main` at the
  fork's base commit, built without the change. The long poll fallback is off
  so both clients reconnect the same way.

## Feedback

Open an issue in this repo with your browser, OS, scenario, and the timeline
lines from the page.
