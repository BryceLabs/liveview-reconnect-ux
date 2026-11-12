defmodule ReconnectDemo.Chaos do
  @moduledoc """
  Global switches that simulate network trouble for every connected tab.

  * an outage refuses new LiveView socket connections until it ends
  * slow mounts make connected mounts sleep past the client's join timeout
  """

  @topic "chaos"

  # phoenix.js waits 10s for a join reply before giving up
  @slow_mount_sleep 12_000

  def topic, do: @topic

  @doc "Drops every LiveView connection, then refuses reconnects for `outage_ms`."
  def drop_all(outage_ms, slow_mount_ms \\ 0) do
    set_until(:outage_until, outage_ms)
    set_until(:slow_mount_until, slow_mount_ms)
    Phoenix.PubSub.broadcast(ReconnectDemo.PubSub, @topic, :drop_connection)
  end

  def outage?, do: active?(:outage_until)
  def slow_mount?, do: active?(:slow_mount_until)
  def slow_mount_sleep, do: @slow_mount_sleep

  defp set_until(key, ms) do
    :persistent_term.put({__MODULE__, key}, now() + ms)
  end

  # monotonic time can be negative, so an unset switch must not default to 0
  defp active?(key) do
    case :persistent_term.get({__MODULE__, key}, nil) do
      nil -> false
      until -> until > now()
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
