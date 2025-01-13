defmodule Lux.SignalSchema do
  @moduledoc """
  A Signal Schema is a schema that describes the data that can be sent between Specters with versioning and metadata support.
  """
  use Lux.Types
  require Record

  @type url :: String.t()
  @type json_schema :: map()

  # given something like this:
  @type t ::
          record(:schema,
            id: String.t(),
            name: String.t(),
            version: String.t(),
            schema: json_schema() | url(),
            created_at: DateTime.t(),
            created_by: String.t(),
            description: String.t(),
            tags: [String.t()],
            compatibility: :full | :partial | :none,
            status: :active | :deprecated | :obsolete,
            format: :json | :binary | :xml | :yaml,
            references: [String.t()]
          )

  Record.defrecord(:schema, __MODULE__,
    id: nil,
    name: "",
    version: "1.0.0",
    schema: %{},
    created_at: nil,
    created_by: nil,
    description: "",
    tags: [],
    compatibility: :full,
    status: :active,
    format: :json,
    references: []
  )

  # # you can then create schemas like this and make them available to all agents:
  # schema(
  #   id: "message-12345",
  #   name: "message",
  #   version: "1.0.0",
  #   schema: %{
  #     type: :object,
  #     properties: %{
  #       message: %{
  #         type: :string
  #       },
  #       from: %{
  #         type: :string
  #       },
  #       to: %{
  #         type: :string
  #       }
  #     }
  #   },
  #   created_at: "2025-01-01T00:00:00Z",
  #   created_by: "not-an-llm",
  #   description: "This is a basic chat message",
  #   tags: [],
  #   compatibility: :full,
  #   status: :active,
  #   format: :json,
  #   references: []
  # )
end
