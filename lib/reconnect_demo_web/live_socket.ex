defmodule ReconnectDemoWeb.LiveSocket do
  @moduledoc """
  The LiveView socket, refusing connections during a simulated outage.
  """
  use Phoenix.LiveView.Socket

  @impl Phoenix.Socket
  def connect(_params, socket, _connect_info) do
    if ReconnectDemo.Chaos.outage?(), do: :error, else: {:ok, socket}
  end

  @impl Phoenix.Socket
  def id(socket), do: Phoenix.LiveView.Socket.id(socket)
end
