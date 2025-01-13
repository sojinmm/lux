defmodule Lux.BeamTest do
  use ExUnit.Case, async: true
  alias Lux.Beam

  defmodule TestBeam do
    use Lux.Beam,
      name: "Test Beam",
      description: "A test beam",
      input_schema: [value: [type: :string]]

    @impl true
    def steps do
      sequence do
        step(:first, TestPrism, %{value: :value})
        step(:first_again, TestPrism, %{value: :value})

        parallel do
          step(:second, TestPrism, %{value: "fixed"}, retries: 2)
          step(:third, TestPrism, %{value: {:ref, "first"}}, store_io: true)
        end

        branch &above_threshold?/1 do
          true -> step(:high, TestPrism, %{value: "high"})
          false -> step(:low, TestPrism, %{value: "low"})
        end
      end
    end

    def above_threshold?(ctx) do
      ctx.first.value > 10
    end
  end

  describe "new/1" do
    test "creates a beam from attributes" do
      attrs = [
        id: "test-1",
        name: "Test Beam",
        description: "A test beam",
        input_schema: [value: [type: :string, required: true]],
        generate_execution_log: true
      ]

      assert %Beam{
               id: id,
               name: name,
               description: description,
               input_schema: input_schema,
               generate_execution_log: generate_execution_log
             } = Beam.new(attrs)

      assert id == "test-1"
      assert name == "Test Beam"
      assert description == "A test beam"
      assert input_schema == [value: [type: :string, required: true]]
      assert generate_execution_log == true
    end

    test "sets default values" do
      beam = Beam.new([])

      assert %Beam{
               timeout: timeout,
               generate_execution_log: generate_execution_log
             } = beam

      assert timeout == :timer.minutes(5)
      assert generate_execution_log == false
    end
  end

  describe "when using Beam" do
    test "defines a beam module with correct attributes" do
      assert %Beam{
               name: "Test Beam",
               description: "A test beam",
               input_schema: [value: [type: :string]]
             } = TestBeam.beam()
    end

    test "serializes step definitions" do
      steps = TestBeam.steps()

      assert {:sequence,
              [
                %{id: "first", module: TestPrism},
                %{id: "first_again", module: TestPrism},
                {:parallel,
                 [
                   %{id: "second", opts: %{retries: 2}},
                   %{id: "third", opts: %{store_io: true}}
                 ]},
                {:branch, {TestBeam, :above_threshold?}, _branches}
              ]} = steps
    end

    test "supports parameter references" do
      steps = TestBeam.steps()

      assert {:sequence,
              [
                %{id: "first", module: TestPrism},
                %{id: "first_again", module: TestPrism},
                {:parallel,
                 [
                   %{id: "second", module: TestPrism, params: %{value: "fixed"}},
                   %{id: "third", module: TestPrism, params: %{value: {:ref, "first"}}}
                 ]},
                _branch
              ]} = steps
    end
  end

  describe "serialization" do
    test "beam can be serialized and deserialized" do
      beam = TestBeam.beam()
      binary = :erlang.term_to_binary(beam)
      deserialized = :erlang.binary_to_term(binary)

      assert beam == deserialized
    end

    test "step definitions can be serialized and deserialized" do
      steps = TestBeam.steps()
      binary = :erlang.term_to_binary(steps)
      deserialized = :erlang.binary_to_term(binary)

      assert steps == deserialized
    end
  end

  describe "step validation" do
    test "validates step IDs are strings" do
      steps = TestBeam.steps()

      assert {:sequence, [first | _rest]} = steps
      assert is_binary(first.id)
      assert first.id == "first"
    end

    test "validates step options have correct defaults" do
      steps = TestBeam.steps()
      {:sequence, [first | _]} = steps

      assert %{opts: opts} = first
      assert opts.timeout == :timer.minutes(5)
      assert opts.retries == 0
      assert opts.retry_backoff == 1000
      assert opts.track == false
      assert opts.dependencies == []
      assert opts.store_io == false
    end

    test "validates step parameters are properly referenced" do
      steps = TestBeam.steps()
      {:sequence, [first | _]} = steps

      assert %{params: %{value: :value}} = first
    end
  end

  describe "branch validation" do
    test "validates branch condition is properly serialized" do
      steps = TestBeam.steps()
      {:sequence, steps_list} = steps
      branch = List.last(steps_list)

      assert {:branch, {TestBeam, :above_threshold?}, branches} = branch
      assert is_list(branches)
      assert Keyword.has_key?(branches, true)
      assert Keyword.has_key?(branches, false)
    end

    test "validates branch steps have correct structure" do
      steps = TestBeam.steps()
      {:sequence, steps_list} = steps
      {:branch, _, branches} = List.last(steps_list)

      high_step = branches[true]
      low_step = branches[false]

      assert high_step.id == "high"
      assert high_step.params.value == "high"
      assert low_step.id == "low"
      assert low_step.params.value == "low"
    end
  end

  # Helper module for tests
  defmodule TestPrism do
    use Lux.Prism

    def handler(input, _ctx) do
      {:ok, input}
    end
  end
end
