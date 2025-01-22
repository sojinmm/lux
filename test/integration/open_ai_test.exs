defmodule Lux.LLM.Integration.OpenAI do
  use IntegrationCase, async: true

  alias Lux.LLM.OpenAI
  alias Lux.LLM.OpenAI.Config, as: LLMConfig
  alias Lux.Signal
  alias Lux.SignalSchema
  alias Lux.LLM.ResponseSignal

  describe "simple text request and response, no tools or structure output" do
    setup do
      config = %LLMConfig{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.7
      }

      %{config: config}
    end

    test "it still returns a structured response", %{config: config} do
      assert {:ok,
              %Signal{
                id: _,
                metadata: %{
                  id: _,
                  usage: %{
                    "completion_tokens" => _,
                    "completion_tokens_details" => %{
                      "accepted_prediction_tokens" => _,
                      "audio_tokens" => _,
                      "reasoning_tokens" => _,
                      "rejected_prediction_tokens" => _
                    },
                    "prompt_tokens" => _,
                    "prompt_tokens_details" => %{
                      "audio_tokens" => 0,
                      "cached_tokens" => _
                    },
                    "total_tokens" => _
                  },
                  created: _,
                  system_fingerprint: _
                },
                payload: %{
                  model: "gpt-4o-mini-2024-07-18",
                  content: %{"capital" => "Paris"},
                  tool_calls: nil,
                  tool_calls_results: nil,
                  finish_reason: "stop"
                },
                recipient: nil,
                schema_id: ResponseSignal,
                sender: nil,
                timestamp: _
              }} = OpenAI.call("What is the capital of France?", [], config)
    end
  end

  describe "Requests with a response schema" do
    defmodule CapitalCitySchema do
      use SignalSchema,
        schema: %{
          type: :object,
          properties: %{
            the_country: %{type: :string, description: "The country name"},
            the_capital: %{type: :string, description: "The capital city name"}
          },
          required: ["the_country", "the_capital"]
        }
    end

    test "will return a structured response according to the schema" do
      config = %LLMConfig{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.7,
        json_schema: CapitalCitySchema
      }

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"the_capital" => "Paris", "the_country" => "France"} = content
                },
                schema_id: ResponseSignal
              }} = OpenAI.call("What is the capital of France?", [], config)

      assert {:ok, _} = CapitalCitySchema.validate(Signal.new(%{payload: content}))
    end
  end

  describe "Requests with prisms and beams (tool calling)" do
    defmodule HashBeam do
      use Lux.Prism,
        name: "#{HashBeam}",
        id: HashBeam,
        description: "Use this to hash a string",
        input_schema: %{
          type: "object",
          properties: %{
            value: %{type: "string", description: "The string to hash"},
            algorithm: %{
              type: "string",
              enum: ["sha256", "sha512"],
              description: "The hashing algorithm to use",
              default: "sha256"
            }
          },
          required: ["value", "algorithm"]
        },
        output_schema: %{
          type: "object",
          properties: %{
            hash: %{type: "string", description: "The hashed string"}
          },
          required: ["hash"]
        }

      def handler(input, _ctx) do
        {:ok, %{hash: input["algorithm"] <> "_hashed_" <> input["value"]}}
      end
    end

    test "will return a function call result in the response" do
      config = %LLMConfig{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.7
      }

      assert {:ok,
              %Signal{
                payload: %{
                  content: nil,
                  tool_calls: [
                    %{
                      "function" => %{
                        "name" => "Elixir_Lux_LLM_Integration_OpenAI_HashBeam",
                        "arguments" => _
                      }
                    }
                  ],
                  tool_calls_results: [%{hash: "sha256_hashed_test"}],
                  finish_reason: "tool_calls"
                },
                schema_id: ResponseSignal
              }} =
               OpenAI.call(
                 "Could you give me the hash of 'test' using sha256?",
                 [HashBeam],
                 config
               )
    end
  end
end
