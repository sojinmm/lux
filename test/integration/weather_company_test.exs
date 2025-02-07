defmodule Lux.Integration.WeatherNewsTeamTest do
  use IntegrationCase, async: true

  alias Lux.Agent
  alias Lux.Company.Runner
  alias Lux.Schemas.TaskSignal
  alias Lux.Signal
  alias Lux.Signal.Router
  alias Lux.Signal.Router.Local

  # Weather Analyst Agent
  defmodule WeatherAnalyst do
    @moduledoc false
    use Lux.Agent

    def new(opts \\ %{}) do
      Agent.new(%{
        name: opts[:name] || "Weather Analyst",
        description: "An AI weather analyst that processes weather data",
        goal: "Analyze weather patterns and provide accurate insights",
        capabilities: [:weather_analysis, :data_processing],
        llm_config: %{
          model: "gpt-3.5-turbo",
          temperature: 0.7,
          api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
          messages: [
            %{
              role: "system",
              content: """
              You are a Weather Analyst specialized in interpreting weather data.
              When receiving weather data, analyze it and provide clear insights.
              For test purposes, generate random but realistic weather data when asked.
              """
            }
          ]
        }
      })
    end

    @impl true
    def handle_signal(_agent, signal) do
      # Simulate weather analysis by generating random data
      weather_data = %{
        temperature: :rand.uniform(35),
        conditions: Enum.random(["sunny", "cloudy", "rainy", "stormy"]),
        humidity: :rand.uniform(100),
        wind_speed: :rand.uniform(30)
      }

      analysis = """
      Weather Analysis for #{signal.payload.task}:
      Temperature: #{weather_data.temperature}°C
      Conditions: #{weather_data.conditions}
      Humidity: #{weather_data.humidity}%
      Wind Speed: #{weather_data.wind_speed} km/h
      """

      # Create analysis response with proper context
      response =
        Signal.new(%{
          id: Lux.UUID.generate(),
          schema_id: TaskSignal,
          payload: %{
            task: signal.payload.task,
            context: %{
              tone: signal.payload.context["editorial_tone"],
              data: analysis
            }
          },
          sender: "weather_analyst",
          recipient: signal.sender
        })

      # Route the response back
      Router.route(response, router: Local)
      :ok
    end
  end

  # News Presenter Agent
  defmodule NewsPresenter do
    @moduledoc false
    use Lux.Agent

    def new(opts \\ %{}) do
      Agent.new(%{
        name: opts[:name] || "News Presenter",
        description: "An AI news presenter that creates engaging weather reports",
        goal: "Create engaging weather reports following the editorial tone",
        capabilities: [:script_writing, :presentation],
        llm_config: %{
          model: "gpt-3.5-turbo",
          temperature: 0.7,
          api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
          messages: [
            %{
              role: "system",
              content: """
              You are a Weather News Presenter.
              Create engaging weather reports following the provided tone and style.
              Keep the reports concise and informative.
              """
            }
          ]
        }
      })
    end

    @impl true
    def handle_signal(_agent, signal) do
      # Create news script response
      response =
        Signal.new(%{
          id: Lux.UUID.generate(),
          schema_id: TaskSignal,
          payload: %{
            result: """
            Weather News Script:
            #{format_news_script(signal.payload)}
            """
          },
          sender: "news_presenter",
          recipient: signal.sender
        })

      Router.route(response, router: Local)
      :ok
    end

    defp format_news_script(%{task: _task, context: %{tone: tone, data: data}}) do
      case tone do
        "formal" ->
          "In today's weather report: #{data}"

        "casual" ->
          "Hey folks! Here's what's happening with the weather: #{data}"

        "dramatic" ->
          "Breaking weather news! #{data}"

        _ ->
          "Today's weather update: #{data}"
      end
    end
  end

  # Weather News Company
  defmodule WeatherNewsTeam do
    @moduledoc false
    use Lux.Company

    company do
      name("Weather News Team")
      mission("Deliver accurate and engaging weather news")

      has_ceo "Editorial Director" do
        agent(TestAgent)
        goal("Direct weather news coverage and set editorial tone")
        can("plan coverage")
        can("set tone")
        can("review content")
      end

      has_member "Weather Expert" do
        agent(WeatherAnalyst)
        goal("Analyze weather data and provide insights")
        can("analyze weather")
        can("process data")
      end

      has_member "News Writer" do
        agent(NewsPresenter)
        goal("Create engaging weather news scripts")
        can("write scripts")
        can("present news")
      end
    end

    plan :create_weather_report do
      input do
        field("coverage_area")
        field("editorial_tone")
      end

      steps("""
      1. Analyze weather data for the area
      2. Create news script with specified tone
      3. Review final content
      """)
    end
  end

  describe "weather news team collaboration" do
    setup do
      # Generate unique names for this test
      test_id = System.unique_integer([:positive])
      router_name = :"signal_router_#{test_id}"
      hub_name = :"agent_hub_#{test_id}"
      runner_name = :"company_runner_#{test_id}"
      task_sup_name = :"task_supervisor_#{test_id}"

      # Start all required processes
      {:ok, _} = start_supervised({Task.Supervisor, name: task_sup_name})
      {:ok, _} = start_supervised({Local, name: router_name})
      {:ok, _} = start_supervised({Lux.AgentHub, name: hub_name})

      # Create company with unique IDs
      company = WeatherNewsTeam.__company__()

      company = %{
        company
        | ceo: Map.put(company.ceo, :id, Lux.UUID.generate()),
          members: Enum.map(company.members, &Map.put(&1, :id, Lux.UUID.generate()))
      }

      # Start the runner with explicit configuration including task supervisor
      {:ok, pid} =
        Runner.start_link(
          {company,
           %{
             router: router_name,
             hub: hub_name,
             name: runner_name,
             task_supervisor: task_sup_name
           }}
        )

      # Register agents with the hub
      :ok =
        Lux.AgentHub.register(hub_name, company.ceo, self(), [
          "plan coverage",
          "set tone",
          "review content"
        ])

      Enum.each(company.members, fn member ->
        :ok = Lux.AgentHub.register(hub_name, member, self(), member.capabilities)
      end)

      {:ok,
       runner: pid,
       runner_name: runner_name,
       company: company,
       router: router_name,
       hub: hub_name,
       task_supervisor: task_sup_name}
    end

    test "creates weather report with specified tone", %{runner_name: runner_name} do
      # Start a weather report plan with specific coverage area and tone
      params = %{
        "coverage_area" => "San Francisco Bay Area",
        "editorial_tone" => "casual"
      }

      {:ok, plan_id} = Runner.run_plan(runner_name, :create_weather_report, params)

      # Wait for plan completion with increased timeout
      assert_receive {:plan_completed, ^plan_id, {:ok, result}}, 10_000

      # Verify all steps were completed
      assert length(result.results) == 3
      [review, script, analysis] = result.results

      # Verify weather analysis step
      assert analysis.task =~ "analyze weather data"
      assert analysis.status == :completed
      assert analysis.result =~ "Weather Analysis"

      # Verify script creation step
      assert script.task =~ "create news script"
      assert script.status == :completed
      assert script.result =~ "Weather News Script"

      # Verify final review step
      assert review.task =~ "review final content"
      assert review.status == :completed
    end

    test "handles different editorial tones", %{runner_name: runner_name} do
      tones = ["formal", "casual", "dramatic"]

      Enum.each(tones, fn tone ->
        params = %{
          "coverage_area" => "New York City",
          "editorial_tone" => tone
        }

        {:ok, plan_id} = Runner.run_plan(runner_name, :create_weather_report, params)
        assert_receive {:plan_completed, ^plan_id, {:ok, result}}, 10_000

        # Get the script creation step result
        script_result = Enum.find(result.results, &(&1.task =~ "create news script"))
        assert script_result.status == :completed

        # Verify the tone is reflected in the script
        case tone do
          "formal" -> assert script_result.result =~ "In today's weather report"
          "casual" -> assert script_result.result =~ "Hey folks"
          "dramatic" -> assert script_result.result =~ "Breaking weather news"
        end
      end)
    end
  end
end
