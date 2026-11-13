defmodule ReconnectDemoWeb.LiveSocket do
  @moduledoc """
  The LiveView socket, refusing a tab's connections during its simulated outage.
  """
  use Phoenix.LiveView.Socket

  alias ReconnectDemo.Chaos

  @impl Phoenix.Socket
  def connect(params, socket, _connect_info) do
    if Chaos.outage?(Chaos.valid_id(params["chaos_id"])), do: :error, else: {:ok, socket}
  end

  @impl Phoenix.Socket
  def id(socket), do: Phoenix.LiveView.Socket.id(socket)
end
