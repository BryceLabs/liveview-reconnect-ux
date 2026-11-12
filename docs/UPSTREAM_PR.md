# Defer phx-disconnected while the page is hidden

Draft description for a pull request from `BryceLabs:reconnect-ux` to
`phoenixframework/phoenix_live_view:main`.

---

## Problem

Coming back to a LiveView tab that has been in the background often shows the
generated "Something went wrong! Attempting to reconnect" toast, even though
the connection recovers a moment later. It makes a healthy app look broken.

This happens because:

- `View.delayedDisconnected` runs `phx-disconnected` commands
  `disconnectedTimeout` (500ms) after a connection error, regardless of page
  visibility.
- phoenix.js deliberately does not reconnect a hidden page
  (`reconnectWhenHidden` defaults to false), and reconnects immediately on
  `visibilitychange`.

So for any drop that happens while the tab is hidden (laptop sleep, network
change, a server deploy, the browser freezing the tab), the disconnected UI is
always on screen when the user returns, and they watch the full reconnect,
join and render with an error toast up.

Separately, `onJoinError` sets `phx-server-error` for join timeouts and
transport failures, even though it already attributes them to the network for
diagnostics. With the generated layout this shows "Something went wrong!" when
the server could not be reached at all.

## Changes

- `phx-disconnected` commands never run while the page is hidden. When the page
  becomes visible again, they wait for the new `disconnectedResumeTimeout`
  LiveSocket option (2000ms by default), giving the immediate reconnect time to
  finish. If the page is hidden again before the timer fires, they are deferred
  again. Reconnecting (`hideLoader`) or destroying the view cancels them.
- The `phx-loading`, `phx-error` and error-kind classes and the
  `phx:page-loading-start` event are still applied immediately, so CSS and the
  generated top bar can still signal that the page is not live.
- `onJoinError` uses `phx-client-error` and `errorKind: "client"` when the join
  timed out or failed in the transport.
- Visible pages behave exactly as before.

Listening for `resume` in addition to `visibilitychange` mirrors the phoenix.js
workaround for Chrome not reliably firing `visibilitychange` when unfreezing a
page.

## Compatibility

Apps that use `phx-disconnected` for something other than UI will see it run
later for drops that happen in background tabs: on return plus the resume
timeout, instead of 500ms after the drop. Apps that need the old timing can
listen for `phx:page-loading-start` with `kind: "error"`, which still fires
immediately.

## Testing

- New unit tests in `assets/test/view_test.ts` cover deferral while hidden, the
  resume timeout, reconnecting before and after the page is visible, hiding
  again mid-timer, `resume` events, destroy, and the join-error classes. They
  fail without the change.
- `npm run js:test`, `npm run js:lint` and `npm run typecheck:tests` pass.
- A demo app comparing stock and patched clients on the same server:
  https://github.com/BryceLabs/liveview-reconnect-ux

## Possible follow-up in the Phoenix generator

The generated `flash_group` shows the same red error toast for a short
reconnect and a real outage. A neutral "Reconnecting…" pill that escalates to
the error toast after a few seconds would pair well with this change, and
needs no new LiveView API.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
