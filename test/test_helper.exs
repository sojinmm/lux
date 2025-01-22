ExUnit.start(exclude: [:skip, :integration, :unit])

defmodule UnitCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :unit
    end
  end
end

defmodule UnitAPICase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :unit
    end
  end

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Application.put_env(:lux, Lux.LLM.OpenAI, plug: {Req.Test, Lux.LLM.OpenAI})

    :ok
  end
end

defmodule IntegrationCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration
    end
  end
end
