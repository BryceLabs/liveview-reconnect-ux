defmodule ReconnectDemoWeb.DemoLive do
  use ReconnectDemoWeb, :live_view

  alias ReconnectDemo.Chaos

  @scenarios %{
    "blip" => %{
      label: "Blip while away",
      outage: 0,
      slow: 0,
      expect:
        "The connection drops while you are on another tab and reconnects the moment you come back. " <>
          "Stock: red toast on return. Patched: nothing (maybe a flash of the top bar)."
    },
    "outage" => %{
      label: "Outage while away",
      outage: 20_000,
      slow: 0,
      expect:
        "The server refuses connections for 20s. Come back during the outage. " <>
          "Stock: toast is already up. Patched: toast appears 2s after you return, because it is a real outage."
    },
    "slow_join" => %{
      label: "Slow rejoin (join timeout)",
      outage: 0,
      slow: 15_000,
      expect:
        "Reconnects work, but mounting takes longer than the 10s join timeout. " <>
          "Stock: \"Something went wrong!\" (server error). Patched: \"We can't find the internet\" (client error). " <>
          "Both reload the page a few seconds later."
    }
  }

  @delay_s 5

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ReconnectDemo.PubSub, Chaos.topic())
      if Chaos.slow_mount?(), do: Process.sleep(Chaos.slow_mount_sleep())
    end

    {:ok,
     assign(socket,
       scenarios: @scenarios,
       pending: nil,
       countdown: 0,
       clicks: 0,
       connected_at: Time.utc_now() |> Time.truncate(:second)
     )}
  end

  @impl true
  def handle_event("arm", %{"scenario" => key}, socket) when is_map_key(@scenarios, key) do
    Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, pending: key, countdown: @delay_s)}
  end

  def handle_event("drop_now", _params, socket) do
    Chaos.drop_all(0)
    {:noreply, socket}
  end

  def handle_event("click", _params, socket) do
    {:noreply, update(socket, :clicks, &(&1 + 1))}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{pending: nil}} = socket), do: {:noreply, socket}

  def handle_info(:tick, %{assigns: %{countdown: n}} = socket) when n > 1 do
    Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, countdown: n - 1)}
  end

  def handle_info(:tick, socket) do
    scenario = @scenarios[socket.assigns.pending]
    Chaos.drop_all(scenario.outage, scenario.slow)
    {:noreply, assign(socket, pending: nil, countdown: 0)}
  end

  def handle_info(:drop_connection, socket) do
    # Killing the transport closes the WebSocket without a clean close frame,
    # like a dropped network connection or a sleeping laptop.
    Process.exit(socket.transport_pid, :kill)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <header class="space-y-2">
          <h1 class="text-2xl font-semibold">LiveView reconnect UX</h1>
          <p class="text-base-content/70">
            Compare how stock LiveView and the
            <a
              class="link"
              href="https://github.com/BryceLabs/phoenix_live_view/tree/reconnect-ux"
            >
              patched client
            </a>
            behave when you come back to a tab whose connection dropped.
          </p>
        </header>

        <section class="flex flex-wrap items-center gap-3">
          <span class="text-sm font-medium">Client:</span>
          <div class="join" id="client-switch" phx-update="ignore">
            <a href="?client=patched" class="btn btn-sm join-item" data-client="patched">
              Patched
            </a>
            <a href="?client=stock" class="btn btn-sm join-item" data-client="stock">
              Stock
            </a>
          </div>
          <span class="text-sm text-base-content/60">
            Connected since {@connected_at} UTC
          </span>
        </section>

        <section class="space-y-3">
          <h2 class="font-semibold">1. Pick a scenario, then switch to another tab</h2>
          <p class="text-sm text-base-content/70">
            The connection drops {delay_s()}s after you click. Stay away for a few
            seconds, then come back and watch the toast in the corner.
          </p>
          <div :if={@pending} class="alert alert-info" id="countdown">
            Dropping in {@countdown}s. Switch tabs now.
          </div>
          <ul class="space-y-3">
            <li :for={{key, s} <- Enum.sort(@scenarios)} class="card bg-base-200 p-4 gap-2">
              <div class="flex items-center justify-between gap-4">
                <span class="font-medium">{s.label}</span>
                <button
                  class="btn btn-primary btn-sm"
                  phx-click="arm"
                  phx-value-scenario={key}
                  disabled={@pending != nil}
                >
                  Start
                </button>
              </div>
              <p class="text-sm text-base-content/70">{s.expect}</p>
            </li>
          </ul>
        </section>

        <section class="space-y-3">
          <h2 class="font-semibold">2. Or drop it while you watch</h2>
          <p class="text-sm text-base-content/70">
            The socket reconnects within milliseconds, so neither client shows a toast.
            This is unchanged.
          </p>
          <div class="flex gap-3">
            <button class="btn btn-sm" phx-click="drop_now">Drop now</button>
            <button class="btn btn-sm" phx-click="click">Clicks: {@clicks}</button>
          </div>
        </section>

        <section class="space-y-2">
          <div class="flex items-center justify-between">
            <h2 class="font-semibold">Timeline for this tab</h2>
            <button class="btn btn-ghost btn-xs" id="clear-timeline">Clear</button>
          </div>
          <ol
            id="timeline"
            phx-update="ignore"
            class="font-mono text-xs bg-base-200 rounded-box p-3 space-y-1 max-h-80 overflow-y-auto"
          >
          </ol>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp delay_s, do: @delay_s
end
