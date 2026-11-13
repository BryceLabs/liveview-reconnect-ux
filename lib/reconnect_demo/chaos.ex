defmodule ReconnectDemo.Chaos do
  @moduledoc """
  Switches that simulate network trouble for a single browser tab.

  Each tab sends a random `chaos_id` with its socket connect params, so on the
  public demo one visitor's simulated outage never affects anyone else.

  * an outage refuses that tab's socket connections until it ends
  * slow mounts make that tab's connected mounts sleep past the join timeout
  """
  use GenServer

  @table __MODULE__
  @sweep_every :timer.minutes(1)

  # phoenix.js waits 10s for a join reply before giving up
  @slow_mount_sleep 12_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def topic(id), do: "chaos:" <> id

  @doc "Returns the chaos id when it is well formed, otherwise nil."
  def valid_id(id) when is_binary(id) and byte_size(id) in 8..64 do
    if id =~ ~r/\A[A-Za-z0-9-]+\z/, do: id
  end

  def valid_id(_id), do: nil

  @doc "Drops the tab's LiveView connection, then refuses its reconnects for `outage_ms`."
  def drop(id, outage_ms, slow_mount_ms \\ 0) do
    set_until(id, :outage, outage_ms)
    set_until(id, :slow_mount, slow_mount_ms)
    Phoenix.PubSub.broadcast(ReconnectDemo.PubSub, topic(id), :drop_connection)
  end

  def outage?(id), do: active?(id, :outage)
  def slow_mount?(id), do: active?(id, :slow_mount)
  def slow_mount_sleep, do: @slow_mount_sleep

  defp set_until(id, kind, ms) when ms > 0, do: :ets.insert(@table, {{id, kind}, now() + ms})
  defp set_until(id, kind, _ms), do: :ets.delete(@table, {id, kind})

  defp active?(nil, _kind), do: false

  defp active?(id, kind) do
    case :ets.lookup(@table, {id, kind}) do
      [{_key, until}] -> until > now()
      [] -> false
    end
  end

  defp now, do: System.monotonic_time(:millisecond)

  @impl true
  def init(nil) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    :ets.select_delete(@table, [{{:_, :"$1"}, [{:<, :"$1", now()}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)
end
