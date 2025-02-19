defmodule Test.Support.Companies.ContentTeam do
  @moduledoc """
  Defines a content creation company for testing purposes.
  Includes a CEO (Content Director), a researcher, and a writer.
  """
  use Lux.Company

  company do
    name("Content Creation Team")
    mission("Create high-quality content efficiently through collaboration")

    has_ceo "Content Director" do
      agent(Test.Support.Agents.ContentDirector)
      goal("Direct content creation and ensure quality")
      can("review")
      can("approve")
      can("plan")
    end

    members do
      has_role "Research Specialist" do
        agent(Test.Support.Agents.Researcher)
        goal("Research topics and provide comprehensive insights")
        can("research")
        can("analyze")
        can("summarize")
      end

      has_role "Content Writer" do
        agent(Test.Support.Agents.Writer)
        goal("Create engaging and well-structured content")
        can("write")
        can("edit")
        can("draft")
      end
    end
  end

  objective :create_blog_post do
    description("Create a well-researched blog post")

    success_criteria(
      "Well-researched content with cited sources, engaging writing style, proper structure, and approved by Content Director"
    )

    steps([
      "Research the topic thoroughly and gather key insights",
      "Create a detailed outline based on research",
      "Write the first draft following the outline",
      "Review and edit the content",
      "Get final approval from Content Director"
    ])
  end
end
