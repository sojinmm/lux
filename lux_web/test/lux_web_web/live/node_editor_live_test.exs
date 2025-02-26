defmodule LuxWebWeb.NodeEditorLiveTest do
  use LuxWebWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "NodeEditorLive" do
    test "renders the node editor interface", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Test that the component palette is rendered
      assert has_element?(view, "h2", "Components")
      assert has_element?(view, "h2", "Properties")

      # Test that the canvas container is rendered
      assert has_element?(view, "#node-editor-canvas")
    end

    test "adds a node when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Create a new node
      new_node = %{
        "id" => "agent-test",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "label" => "Test Agent",
          "description" => "Test description",
          "goal" => "Test goal",
          "components" => []
        }
      }

      # Send the node_added event
      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => new_node})

      # Verify that the node was added
      html = render(view)
      assert html =~ "Test Agent"
      assert html =~ "Test description"
    end

    test "removes a node when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First add a node
      new_node = %{
        "id" => "agent-to-remove",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "label" => "Agent to Remove",
          "description" => "Test description",
          "goal" => "Test goal",
          "components" => []
        }
      }

      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => new_node})

      # Verify the node was added
      html = render(view)
      assert html =~ "Agent to Remove"
      assert html =~ "Test description"

      # Now remove the node
      view |> element("#node-editor-canvas") |> render_hook("node_removed", %{"id" => "agent-to-remove"})

      # Verify the node was removed
      html = render(view)
      refute html =~ "Agent to Remove"
    end

    test "selects a node when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First add a node
      new_node = %{
        "id" => "agent-to-select",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "label" => "Agent to Select",
          "description" => "Test description",
          "goal" => "Test goal",
          "components" => []
        }
      }

      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => new_node})

      # Initially no node should be selected
      assert render(view) =~ "Select a node to view and edit its properties"

      # Select the node
      view |> element("g.node[data-node-id='agent-to-select']") |> render_click()

      # Verify the node was selected
      html = render(view)
      assert html =~ "Agent to Select"
      assert html =~ "Test description"
      assert html =~ "Test goal"
    end

    test "adds an edge when event is received", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First add two nodes
      source_node = %{
        "id" => "agent-source",
        "type" => "agent",
        "position" => %{"x" => 100, "y" => 100},
        "data" => %{
          "label" => "Source Agent",
          "description" => "Test description"
        }
      }

      target_node = %{
        "id" => "prism-target",
        "type" => "prism",
        "position" => %{"x" => 300, "y" => 100},
        "data" => %{
          "label" => "Target Prism",
          "description" => "Test description"
        }
      }

      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => source_node})
      view |> element("#node-editor-canvas") |> render_hook("node_added", %{"node" => target_node})

      # Start drawing the edge
      view |> element("#node-editor-canvas") |> render_hook("edge_started", %{"source_id" => "agent-source"})

      # Complete the edge
      view |> element("#node-editor-canvas") |> render_hook("edge_completed", %{"target_id" => "prism-target"})

      # Verify that the edge was added
      html = render(view)
      assert html =~ "edge-agent-source-prism-target"
      assert html =~ "agent-source"
      assert html =~ "prism-target"
    end

    test "renders initial state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Check that the page renders with basic structure
      assert html =~ "Components"
      assert html =~ "Properties"
      assert html =~ "Ultimate Assistant"
      assert html =~ "Tools Agent"
    end

    test "selecting a node updates the properties panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial state should show "Select a node" message
      assert render(view) =~ "Select a node to view and edit its properties"

      # Click the node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Properties panel should now show the node's details
      html = render(view)
      assert html =~ "Ultimate Assistant" # Node name in form
      assert html =~ "Tools Agent" # Node description in form
      assert html =~ "Help users with various tasks" # Node goal in form
    end

    test "selecting different nodes updates the properties panel correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a second node through a node_added event
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-1",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "label" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      # Select first node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Check first node's properties
      html = render(view)
      assert html =~ "Ultimate Assistant"
      assert html =~ "Tools Agent"
      assert html =~ "Help users with various tasks"

      # Select second node
      view
      |> element("g.node[data-node-id='prism-1']")
      |> render_click()

      # Check second node's properties
      html = render(view)
      assert html =~ "Test Prism"
      assert html =~ "Test Description"
      refute html =~ "Help users with various tasks" # Goal field should not be present for non-agent nodes
    end

    test "deselecting a node clears the properties panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First select a node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Verify node is selected
      assert render(view) =~ "Ultimate Assistant"

      # Click somewhere else on the canvas to deselect
      view
      |> element("#node-editor-canvas")
      |> render_click()

      # Verify node is deselected
      assert render(view) =~ "Select a node to view and edit its properties"
    end

    test "updating agent properties updates both panel and node display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select the initial agent node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Update the properties
      attrs = %{
        "node" => %{
          "id" => "agent-1",
          "data" => %{
            "label" => "Updated Agent Name",
            "description" => "Updated Description",
            "goal" => "Updated Goal"
          }
        }
      }

      view
      |> form("form", attrs)
      |> render_submit()

      # Verify updates in the rendered HTML
      html = render(view)

      # Check properties panel
      assert html =~ "Updated Agent Name"
      assert html =~ "Updated Description"
      assert html =~ "Updated Goal"

      # Check node display on canvas
      assert html =~ ~s(<text x="10" y="30" fill="white" font-weight="bold">Updated Agent Name</text>)
      assert html =~ ~s(<text x="10" y="50" fill="#999" font-size="12">Updated Description</text>)
    end

    test "updating prism properties updates both panel and node display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a prism node first
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-test",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "label" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      # Select the prism node
      view
      |> element("g.node[data-node-id='prism-test']")
      |> render_click()

      # Update the properties
      attrs = %{
        "node" => %{
          "id" => "prism-test",
          "data" => %{
            "label" => "Updated Prism Name",
            "description" => "Updated Prism Description"
          }
        }
      }

      view
      |> form("form", attrs)
      |> render_submit()

      # Verify updates in the rendered HTML
      html = render(view)

      # Check properties panel
      assert html =~ "Updated Prism Name"
      assert html =~ "Updated Prism Description"

      # Check node display on canvas
      assert html =~ ~s(<text x="10" y="30" fill="white" font-weight="bold">Updated Prism Name</text>)
      assert html =~ ~s(<text x="10" y="50" fill="#999" font-size="12">Updated Prism Description</text>)

      # Verify that goal field is not present for prism nodes
      refute html =~ "Goal"
    end

    test "node description updates are reflected in the SVG display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select the initial agent node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Update just the description
      attrs = %{
        "node" => %{
          "id" => "agent-1",
          "data" => %{
            "label" => "Ultimate Assistant",  # Keep original name
            "description" => "This is a new description that should appear in the node",
            "goal" => "Help users with various tasks"  # Keep original goal
          }
        }
      }

      view
      |> form("form", attrs)
      |> render_submit()

      # Get the rendered HTML
      html = render(view)

      # Check properties panel
      assert html =~ "This is a new description that should appear in the node"

      # Check the exact SVG text element for description (y=50 is where description appears)
      assert html =~ ~s(<text x="10" y="50" fill="#999" font-size="12">This is a new description that should appear in the node</text>)

      # Verify the label and goal weren't changed
      assert html =~ ~s(<text x="10" y="30" fill="white" font-weight="bold">Ultimate Assistant</text>)
      assert html =~ "Help users with various tasks"
    end

    test "updates node properties in real-time when pressing cmd+enter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Select the initial agent node
      view
      |> element("g.node[data-node-id='agent-1']")
      |> render_click()

      # Test label update with cmd+enter
      view
      |> element("input[name='node[data][label]']")
      |> render_keydown(%{"key" => "Enter", "metaKey" => true, "value" => "Real-time Label Update"})

      html = render(view)
      assert html =~ "Real-time Label Update"
      assert html =~ ~s(<text x="10" y="30" fill="white" font-weight="bold">Real-time Label Update</text>)

      # Test description update with cmd+enter
      view
      |> element("textarea[name='node[data][description]']")
      |> render_keydown(%{"key" => "Enter", "metaKey" => true, "value" => "Real-time Description Update"})

      html = render(view)
      assert html =~ "Real-time Description Update"
      assert html =~ ~s(<text x="10" y="50" fill="#999" font-size="12">Real-time Description Update</text>)

      # Test goal update with cmd+enter (only for agent nodes)
      view
      |> element("textarea[name='node[data][goal]']")
      |> render_keydown(%{"key" => "Enter", "metaKey" => true, "value" => "Real-time Goal Update"})

      html = render(view)
      assert html =~ "Real-time Goal Update"
    end

    test "updates prism properties in real-time when pressing ctrl+enter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add and select a prism node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-test",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "label" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      view
      |> element("g.node[data-node-id='prism-test']")
      |> render_click()

      # Test label update with ctrl+enter
      view
      |> element("input[name='node[data][label]']")
      |> render_keydown(%{"key" => "Enter", "ctrlKey" => true, "value" => "Real-time Prism Update"})

      html = render(view)
      assert html =~ "Real-time Prism Update"
      assert html =~ ~s(<text x="10" y="30" fill="white" font-weight="bold">Real-time Prism Update</text>)

      # Test description update with ctrl+enter
      view
      |> element("textarea[name='node[data][description]']")
      |> render_keydown(%{"key" => "Enter", "ctrlKey" => true, "value" => "Real-time Prism Description"})

      html = render(view)
      assert html =~ "Real-time Prism Description"
      assert html =~ ~s(<text x="10" y="50" fill="#999" font-size="12">Real-time Prism Description</text>)

      # Verify goal field is not present for prism nodes
      refute has_element?(view, "textarea[name='node[data][goal]']")
    end

    test "dragging a node updates its position in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial position check for agent-1
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]

      # Simulate mouse down on the node
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Simulate mouse move while dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 500,
        "clientY" => 300,
        "movementX" => 100,
        "movementY" => 100
      })

      # Verify position updated during drag
      html = render(view)
      assert html =~ ~s[transform="translate(500,300)"]

      # Simulate mouse up to complete drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})

      # Verify final position
      html = render(view)
      assert html =~ ~s[transform="translate(500,300)"]
    end

    test "dragging snaps to grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Start drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Move to non-grid position
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 433,
        "clientY" => 267,
        "movementX" => 33,
        "movementY" => 67
      })

      # Verify position snapped to grid (20px)
      html = render(view)
      assert html =~ ~s[transform="translate(440,260)"]

      # Complete drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end

    test "dragging respects canvas bounds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Start drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Try to drag beyond left/top bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => -100,
        "clientY" => -50,
        "movementX" => -500,
        "movementY" => -250
      })

      # Verify position constrained to minimum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(0,0)"]

      # Try to drag beyond right/bottom bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 2500,
        "clientY" => 1500,
        "movementX" => 2600,
        "movementY" => 1550
      })

      # Verify position constrained to maximum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(1720,980)"]

      # Complete drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end

    test "escape key cancels dragging", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial position
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]

      # Start drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Move during drag
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 500,
        "clientY" => 300,
        "movementX" => 100,
        "movementY" => 100
      })

      # Press escape
      view
      |> element("#node-editor-canvas")
      |> render_hook("keydown", %{"key" => "Escape"})

      # Verify position reverted
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]
    end

    test "dragging maintains edge connections", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add a second node
      view
      |> element("#node-editor-canvas")
      |> render_hook("node_added", %{
        "node" => %{
          "id" => "prism-1",
          "type" => "prism",
          "position" => %{"x" => 600, "y" => 200},
          "data" => %{
            "label" => "Test Prism",
            "description" => "Test Description"
          }
        }
      })

      # Create an edge
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_started", %{"source_id" => "agent-1"})
      view
      |> element("#node-editor-canvas")
      |> render_hook("edge_completed", %{"target_id" => "prism-1"})

      # Verify edge exists
      html = render(view)
      assert html =~ "edge-agent-1-prism-1"

      # Drag source node
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 300,
        "clientY" => 300,
        "movementX" => -100,
        "movementY" => 100
      })

      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})

      # Verify edge still exists after drag
      html = render(view)
      assert html =~ "edge-agent-1-prism-1"
    end

    test "dragging multiple nodes maintains their relative positions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Add two more nodes at specific positions
      nodes = [
        %{
          "id" => "lens-1",
          "type" => "lens",
          "position" => %{"x" => 200, "y" => 300},
          "data" => %{
            "label" => "Test Lens",
            "description" => "Test Lens Description"
          }
        },
        %{
          "id" => "beam-1",
          "type" => "beam",
          "position" => %{"x" => 700, "y" => 400},
          "data" => %{
            "label" => "Test Beam",
            "description" => "Test Beam Description"
          }
        }
      ]

      # Add the nodes
      for node <- nodes do
        view
        |> element("#node-editor-canvas")
        |> render_hook("node_added", %{"node" => node})
      end

      # Verify initial positions
      html = render(view)
      assert html =~ ~s[transform="translate(200,300)"]  # lens-1
      assert html =~ ~s[transform="translate(700,400)"]  # beam-1
      assert html =~ ~s[transform="translate(400,200)"]  # agent-1 (initial node)

      # Drag each node to new positions
      positions = [
        {"lens-1", 250, 350},
        {"beam-1", 750, 450},
        {"agent-1", 450, 250}
      ]

      for {node_id, x, y} <- positions do
        view
        |> element("#node-editor-canvas")
        |> render_hook("node_dragged", %{
          "node_id" => node_id,
          "x" => x,
          "y" => y
        })
      end

      # Verify all nodes moved to their new positions
      html = render(view)
      assert html =~ ~s[transform="translate(250,350)"]  # lens-1
      assert html =~ ~s[transform="translate(750,450)"]  # beam-1
      assert html =~ ~s[transform="translate(450,250)"]  # agent-1
    end

    test "dragging updates node position in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate dragging motion with multiple position updates
      positions = [
        {450, 250},
        {500, 300},
        {550, 350},
        {600, 400}
      ]

      # Apply each position update and verify it takes effect immediately
      for {x, y} <- positions do
        view
        |> element("#node-editor-canvas")
        |> render_hook("node_dragged", %{
          "node_id" => "agent-1",
          "x" => x,
          "y" => y
        })

        html = render(view)
        assert html =~ ~s[transform="translate(#{x},#{y})"]
      end
    end

    test "NodeDraggable hook initiates dragging correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Initial position check
      html = render(view)
      assert html =~ ~s[transform="translate(400,200)"]

      # Simulate mousedown on the node via the NodeDraggable hook
      view
      |> element("#node-agent-1")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 420,
        "clientY" => 220
      })

      # Simulate mousemove on the canvas
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 440,
        "clientY" => 240
      })

      # Verify position updated
      html = render(view)
      assert html =~ ~s[transform="translate(420,220)"]

      # Simulate mouseup to end dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})

      # Verify position remains at the last position
      html = render(view)
      assert html =~ ~s[transform="translate(420,220)"]
    end

    test "dragging with NodeDraggable respects grid snapping", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate mousedown on the node
      view
      |> element("#node-agent-1")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Simulate mousemove to a non-grid position
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 427,
        "clientY" => 213
      })

      # Verify position snapped to grid (20px)
      html = render(view)
      assert html =~ ~s[transform="translate(420,220)"]

      # End dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end

    test "dragging with NodeDraggable respects canvas bounds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate mousedown on the node
      view
      |> element("#node-agent-1")
      |> render_hook("mousedown", %{
        "node_id" => "agent-1",
        "clientX" => 400,
        "clientY" => 200
      })

      # Try to drag beyond left/top bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => -100,
        "clientY" => -50
      })

      # Verify position constrained to minimum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(0,0)"]

      # Try to drag beyond right/bottom bounds
      view
      |> element("#node-editor-canvas")
      |> render_hook("mousemove", %{
        "clientX" => 2500,
        "clientY" => 1500
      })

      # Verify position constrained to maximum bounds
      html = render(view)
      assert html =~ ~s[transform="translate(1720,980)"]

      # End dragging
      view
      |> element("#node-editor-canvas")
      |> render_hook("mouseup", %{})
    end
  end
end
