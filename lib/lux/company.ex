defmodule Lux.Company do
  @moduledoc """
  Defines a company structure for coordinating agent-based workflows.

  Companies are the highest-level organizational unit in Lux, consisting of:
  - A CEO agent for coordination and decision making
  - Member agents with specific roles and capabilities
  - Plans that define workflows to be executed

  ## Example

      defmodule MyApp.Companies.BlogTeam do
        use Lux.Company

        company do
          name "Content Creation Lab"
          mission "Create high-quality, research-backed blog content"

          has_ceo "Content Director" do
            agent MyApp.Agents.ContentDirector
            goal "Coordinate the team and ensure high-quality content delivery"
            can "plan content strategy"
            can "review and approve content"
          end

          has_member "Research Specialist" do
            agent MyApp.Agents.Researcher
            goal "Find and analyze relevant information"
            can "conduct web research"
            can "analyze data"
          end
        end

        plan :create_blog_post do
          input do
            field "Topic to write about"
            field "Target audience"
          end

          steps \"\"\"
          1. Research the topic thoroughly
          2. Create a detailed outline
          3. Write the first draft
          \"\"\"
        end
      end
  """

  use Supervisor

  alias Lux.Company.Plan
  alias Lux.Company.Role

  defstruct [:id, :name, :mission, :ceo, :members, :plans]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          mission: String.t(),
          ceo: Role.t(),
          members: [Role.t()],
          plans: %{atom() => Plan.t()}
        }

  @doc """
  Starts a company supervisor.
  """
  def start_link(module, opts \\ []) when is_atom(module) do
    Supervisor.start_link(__MODULE__, {module, opts}, name: name_for_module(module, opts))
  end

  @doc """
  Runs a plan within the company context.
  """
  def run_plan(company, plan_name, params) when is_atom(plan_name) do
    GenServer.call(name_for_company(company), {:run_plan, plan_name, params})
  end

  # Supervisor callbacks

  @impl true
  def init({module, opts}) do
    company = module.__company__()

    children = [
      # CEO supervisor
      {Lux.Company.CEOSupervisor, {company.ceo, opts}},
      # Member agents supervisor
      {Lux.Company.MemberSupervisor, {company.members, opts}},
      # Company runner for executing plans
      {Lux.Company.Runner, {company, opts}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Private helpers

  defp name_for_module(module, opts) do
    opts[:name] || Module.concat(module, "Supervisor")
  end

  defp name_for_company(company) when is_atom(company) do
    Module.concat(company, "Supervisor")
  end

  defmacro __using__(_opts) do
    quote do
      import Lux.Company.DSL

      Module.register_attribute(__MODULE__, :company_config, accumulate: false)
      @before_compile Lux.Company
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __company__ do
        @company_config
      end
    end
  end
end
