defmodule LuxTest do
  use ExUnit.Case
  doctest Lux

  test "greets the world" do
    assert Lux.hello() == :world
  end
end
