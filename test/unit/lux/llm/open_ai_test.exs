defmodule Lux.LLM.OpenAITest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenAI
  alias Lux.LLM.Response

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism
  require Response

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts a beam to an OpenAI function" do
      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{
                type: "string",
                description: "Test value"
              },
              "amount" => %{
                type: "float",
                description: "Test amount"
              }
            }
          }
        )

      function = OpenAI.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "TestBeam",
                 description: "A test beam",
                 parameters: %{
                   type: "object",
                   properties: %{
                     "value" => %{
                       type: "string",
                       description: "Test value"
                     },
                     "amount" => %{
                       type: "float",
                       description: "Test amount"
                     }
                   }
                 }
               }
             } = function
    end

    test "converts a prism to an OpenAI function" do
      prism =
        Lux.Prism.new(%{
          name: "test_prism",
          description: "A test prism",
          input_schema: %{
            type: "object",
            properties: %{
              "query" => %{
                type: "string",
                description: "Search query"
              }
            }
          }
        })

      function = OpenAI.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "test_prism",
                 description: "A test prism",
                 parameters: %{
                   type: "object",
                   properties: %{
                     "query" => %{
                       type: "string",
                       description: "Search query"
                     }
                   }
                 }
               }
             } = function
    end

    test "converts a lens to an OpenAI function" do
      lens =
        Lux.Lens.new(
          name: "WeatherAPI",
          description: "Gets weather data",
          schema: %{
            type: "object",
            properties: %{
              location: %{
                type: "string",
                description: "City name"
              },
              units: %{
                type: "string",
                description: "Temperature units"
              }
            }
          }
        )

      function = OpenAI.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "WeatherAPI",
                 description: "Gets weather data",
                 parameters: %{
                   type: "object",
                   properties: %{
                     location: %{
                       type: "string",
                       description: "City name"
                     },
                     units: %{
                       type: "string",
                       description: "Temperature units"
                     }
                   }
                 }
               }
             } = function
    end
  end

  describe "call/3" do
    test "makes correct API call with tools" do
      config = %OpenAI.Config{
        api_key: "test_key",
        model: "gpt-3.5-turbo"
      }

      beam =
        Lux.Beam.new(
          name: "TestBeam",
          description: "A test beam",
          input_schema: %{
            type: "object",
            properties: %{
              "value" => %{
                type: "string",
                description: "Test value"
              }
            }
          }
        )

      Req.Test.expect(OpenAI, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "gpt-3.5-turbo"
        assert [%{"role" => "user", "content" => "test prompt"}] = decoded_body["messages"]
        assert [tool] = decoded_body["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "TestBeam"

        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "content" => "Test response"
              },
              "finish_reason" => "stop"
            }
          ]
        })
      end)

      assert {:ok, response} = OpenAI.call("test prompt", [beam], config: config)
      assert ^response = Response.response(content: "Test response", finish_reason: "stop")
    end

    test "handles tool call responses" do
      config = %OpenAI.Config{
        api_key: "test_key",
        model: "gpt-3.5-turbo"
      }

      Req.Test.expect(OpenAI, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [
            %{
              "message" => %{
                "tool_calls" => [
                  %{
                    "type" => "function",
                    "function" => %{
                      "name" => "TestBeam",
                      "arguments" => ~s({"value": "test"})
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ]
        })
      end)

      assert {:ok, response} = OpenAI.call("test prompt", [], config)

      assert ^response =
               Response.response(
                 tool_calls: [%{type: "function", name: "TestBeam", params: %{"value" => "test"}}],
                 finish_reason: "tool_calls"
               )
    end
  end
end
