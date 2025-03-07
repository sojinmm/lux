defmodule Lux.Lenses.Etherscan.DailyUncleBlockCountLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.DailyUncleBlockCount

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: true
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response with default sort parameter" do
      # Set up the test parameters
      params = %{
        startdate: "2019-02-01",
        enddate: "2019-02-28",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "dailyuncleblkcount"
        assert query["startdate"] == "2019-02-01"
        assert query["enddate"] == "2019-02-28"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "UTCDate" => "2019-02-01",
              "uncleBlockCount" => "100",
              "uncleBlockRewards" => "2000"
            },
            %{
              "UTCDate" => "2019-02-02",
              "uncleBlockCount" => "96",
              "uncleBlockRewards" => "1920"
            }
          ]
        })
      end)

      # Call the lens
      result = DailyUncleBlockCount.focus(params)

      # Verify the result
      assert {:ok, %{result: uncle_data}} = result
      assert length(uncle_data) == 2

      # Verify first day's data
      first_day = Enum.at(uncle_data, 0)
      assert first_day.date == "2019-02-01"
      assert first_day.uncle_blocks_count == "100"
      assert first_day.uncle_blocks_rewards_eth == "2000"

      # Verify second day's data
      second_day = Enum.at(uncle_data, 1)
      assert second_day.date == "2019-02-02"
      assert second_day.uncle_blocks_count == "96"
      assert second_day.uncle_blocks_rewards_eth == "1920"
    end

    test "makes correct API call and processes the response with 'desc' sort parameter" do
      # Set up the test parameters
      params = %{
        startdate: "2019-02-01",
        enddate: "2019-02-28",
        sort: "desc",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["sort"] == "desc"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "UTCDate" => "2019-02-28",
              "uncleBlockCount" => "104",
              "uncleBlockRewards" => "2080"
            },
            %{
              "UTCDate" => "2019-02-27",
              "uncleBlockCount" => "102",
              "uncleBlockRewards" => "2040"
            }
          ]
        })
      end)

      # Call the lens
      result = DailyUncleBlockCount.focus(params)

      # Verify the result
      assert {:ok, %{result: uncle_data}} = result
      assert length(uncle_data) == 2

      # Verify first day's data (should be the latest date due to desc sorting)
      first_day = Enum.at(uncle_data, 0)
      assert first_day.date == "2019-02-28"
      assert first_day.uncle_blocks_count == "104"
      assert first_day.uncle_blocks_rewards_eth == "2080"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid data
      params = %{
        startdate: "invalid-date",
        enddate: "2019-02-28",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid date format"
        })
      end)

      # Call the lens
      result = DailyUncleBlockCount.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid date format"}} = result
    end

    test "handles Pro API key errors" do
      # Set up test API key without Pro access
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Set up the test parameters
      params = %{
        startdate: "2019-02-01",
        enddate: "2019-02-28",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a Pro API key error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid API Key"
        })
      end)

      # Call the lens
      result = DailyUncleBlockCount.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly with default sort" do
      # Set up the test parameters without sort
      params = %{
        startdate: "2019-02-01",
        enddate: "2019-02-28",
        chainid: 1
      }

      # Call the function
      result = DailyUncleBlockCount.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "dailyuncleblkcount"
      assert result.startdate == "2019-02-01"
      assert result.enddate == "2019-02-28"
      assert result.sort == "asc"
      assert result.chainid == 1
    end

    test "prepares parameters correctly with specified sort" do
      # Set up the test parameters with sort
      params = %{
        startdate: "2019-02-01",
        enddate: "2019-02-28",
        sort: "desc",
        chainid: 1
      }

      # Call the function
      result = DailyUncleBlockCount.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "dailyuncleblkcount"
      assert result.startdate == "2019-02-01"
      assert result.enddate == "2019-02-28"
      assert result.sort == "desc"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "UTCDate" => "2019-02-01",
            "uncleBlockCount" => "100",
            "uncleBlockRewards" => "2000"
          },
          %{
            "UTCDate" => "2019-02-02",
            "uncleBlockCount" => "96",
            "uncleBlockRewards" => "1920"
          }
        ]
      }

      # Call the function
      result = DailyUncleBlockCount.after_focus(response)

      # Verify the result
      assert {:ok, %{result: uncle_data}} = result
      assert length(uncle_data) == 2

      # Verify first day's data
      first_day = Enum.at(uncle_data, 0)
      assert first_day.date == "2019-02-01"
      assert first_day.uncle_blocks_count == "100"
      assert first_day.uncle_blocks_rewards_eth == "2000"

      # Verify second day's data
      second_day = Enum.at(uncle_data, 1)
      assert second_day.date == "2019-02-02"
      assert second_day.uncle_blocks_count == "96"
      assert second_day.uncle_blocks_rewards_eth == "1920"
    end

    test "processes empty result" do
      # Create a mock response with empty result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => []
      }

      # Call the function
      result = DailyUncleBlockCount.after_focus(response)

      # Verify the result
      assert {:ok, %{result: uncle_data}} = result
      assert uncle_data == []
    end

    test "processes Pro API key error" do
      # Create a mock Pro API key error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid API Key"
      }

      # Call the function
      result = DailyUncleBlockCount.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end

    test "processes general error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid date format"
      }

      # Call the function
      result = DailyUncleBlockCount.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid date format"}} = result
    end
  end
end
