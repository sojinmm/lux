defmodule Lux.Prisms.AgenticCompany.FormatOutputPrism do
  @moduledoc """
  A helper prism that formats the output of the company setup workflow.

  This prism takes the company address and job creation results and formats them
  into the final output structure.
  """

  use Lux.Prism,
    name: "Format Company Setup Output",
    description: "Formats the company and job creation results into the final output structure",
    input_schema: %{
      type: :object,
      properties: %{
        company_address: %{
          type: :string,
          description: "Address of the newly created company"
        },
        job_results: %{
          type: :object,
          properties: %{
            jobs: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  name: %{type: :string},
                  job_id: %{type: :string}
                }
              }
            }
          },
          required: [:jobs]
        }
      },
      required: [:company_address, :job_results]
    },
    output_schema: %{
      type: :object,
      properties: %{
        company_address: %{type: :string, description: "Address of the newly created company"},
        jobs: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              job_id: %{type: :string}
            }
          }
        }
      },
      required: [:company_address, :jobs]
    }

  def handler(%{company_address: company_address, job_results: %{jobs: jobs}}, _ctx) do
    {:ok,
     %{
       company_address: company_address,
       jobs: jobs
     }}
  end
end
