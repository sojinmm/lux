defmodule LuxTest do
  use UnitCase
  doctest Lux

  test "greets the world", ctx do
    assert Lux.hello() == :world
  end
end
