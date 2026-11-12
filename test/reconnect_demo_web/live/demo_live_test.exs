defmodule ReconnectDemoWeb.DemoLiveTest do
  use ReconnectDemoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "renders the scenarios", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Blip while away"
    assert html =~ "Outage while away"
    assert html =~ "Slow rejoin"
  end

  test "arming a scenario counts down", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert view |> element("button[phx-value-scenario=blip]") |> render_click() =~
             "Dropping in 5s"
  end

  test "an outage refuses socket connections until it ends" do
    ReconnectDemo.Chaos.drop_all(50)
    assert ReconnectDemo.Chaos.outage?()
    assert ReconnectDemoWeb.LiveSocket.connect(%{}, %Phoenix.Socket{}, %{}) == :error
    Process.sleep(60)
    refute ReconnectDemo.Chaos.outage?()
  end
end
