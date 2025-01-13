defmodule Lux.Signal do
  @moduledoc """
  A signal represents messages that can be sent between Specters.
  """
  import Lux.Types
  require Record

  Record.defrecord(:signal, __MODULE__, [
    :id,
    :schema_id,
    :content
  ])

  @type t :: record(:signal, id: String.t(), schema_id: String.t(), content: any())

  defmacro __using__(_opts) do
    quote do
      import Lux.Signal
    end
  end
end
