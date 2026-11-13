defmodule ReconnectDemoWeb.DemoLiveTest do
  use ReconnectDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ReconnectDemo.Chaos

  defp chaos_id, do: "test-tab-" <> Integer.to_string(System.unique_integer([:positive]))

  test "renders the scenarios", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Blip while away"
    assert html =~ "Outage while away"
    assert html =~ "Slow rejoin"
  end

  test "arming a scenario counts down", %{conn: conn} do
    conn = put_connect_params(conn, %{"chaos_id" => chaos_id()})
    {:ok, view, _html} = live(conn, ~p"/")

    assert view |> element("button[phx-value-scenario=blip]") |> render_click() =~
             "Dropping in 5s"
  end

  test "scenarios need a chaos id", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert view |> element("button", "Drop now") |> render_click() =~ "no chaos id"
  end

  test "an outage only refuses the tab that started it" do
    id = chaos_id()
    Chaos.drop(id, 60_000)

    assert Chaos.outage?(id)
    refute Chaos.outage?(chaos_id())

    assert ReconnectDemoWeb.LiveSocket.connect(%{"chaos_id" => id}, %Phoenix.Socket{}, %{}) ==
             :error

    assert {:ok, _socket} =
             ReconnectDemoWeb.LiveSocket.connect(
               %{"chaos_id" => chaos_id()},
               %Phoenix.Socket{},
               %{}
             )
  end

  test "an outage ends" do
    id = chaos_id()
    Chaos.drop(id, 1)
    Process.sleep(5)
    refute Chaos.outage?(id)
  end

  test "rejects malformed chaos ids" do
    assert Chaos.valid_id("2b1f6c2e-8d0a-4c55-9a43-0f3a8d3c9e11")
    refute Chaos.valid_id("short")
    refute Chaos.valid_id("has spaces in it")
    refute Chaos.valid_id(String.duplicate("a", 65))
    refute Chaos.valid_id(nil)
  end
end
