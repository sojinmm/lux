const NodeEditorHooks = {
  DraggableNode: {
    mounted() {
      this.el.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('node-type', this.el.dataset.type);
      });
    }
  },

  NodeDraggable: {
    mounted() {
      this.el.addEventListener('mousedown', (e) => {
        // Only handle left mouse button
        if (e.button !== 0) return;
        
        // Get the node ID from the data attribute
        const nodeId = this.el.dataset.nodeId;
        
        // Get SVG element for coordinate calculations
        const svg = document.querySelector('#node-editor-canvas svg');
        const svgRect = svg.getBoundingClientRect();
        
        // Calculate mouse position relative to SVG
        const mouseX = e.clientX - svgRect.left;
        const mouseY = e.clientY - svgRect.top;
        
        console.log(`NodeDraggable: mousedown on node ${nodeId} at position (${mouseX}, ${mouseY})`);
        
        // Push event to the canvas hook
        this.pushEventTo('#node-editor-canvas', 'mousedown', {
          node_id: nodeId,
          clientX: mouseX,
          clientY: mouseY
        });
        
        e.preventDefault();
      });
    }
  },

  NodeCanvas: {
    mounted() {
      this.isDragging = false;
      this.draggedNode = null;
      this.isDrawingEdge = false;
      this.startPort = null;
      this.mousePosition = { x: 0, y: 0 };
      this.dragStartPosition = { x: 0, y: 0 };

      // Get SVG element for coordinate calculations
      this.svg = this.el.querySelector('svg');

      // Setup event listeners
      this.el.addEventListener('dragover', this.handleDragOver.bind(this));
      this.el.addEventListener('drop', this.handleDrop.bind(this));
      this.el.addEventListener('mousemove', this.handleMouseMove.bind(this));

      // Setup node dragging event listeners
      this.el.addEventListener('mousedown', this.handleNodeMouseDown.bind(this));
      document.addEventListener('mousemove', this.handleNodeDrag.bind(this));
      document.addEventListener('mouseup', this.handleNodeMouseUp.bind(this));
      document.addEventListener('keydown', this.handleKeyDown.bind(this));
      
      // Setup port event listeners
      this.setupPortListeners();
      
      // Setup edge path calculations
      this.updateEdgePaths();
    },

    destroyed() {
      // Cleanup event listeners if needed
    },

    handleDragOver(e) {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
    },

    handleDrop(e) {
      e.preventDefault();
      const nodeType = e.dataTransfer.getData('node-type');
      if (!nodeType) return;

      const svgRect = this.svg.getBoundingClientRect();
      const x = e.clientX - svgRect.left;
      const y = e.clientY - svgRect.top;

      // Generate a unique ID for the new node
      const nodeId = `${nodeType}-${Date.now()}`;

      // Push the new node to the server
      this.pushEvent('node_added', {
        node: {
          id: nodeId,
          type: nodeType,
          position: { x, y },
          data: this.getInitialNodeData(nodeType)
        }
      });
    },

    handleMouseMove(e) {
      const svgRect = this.svg.getBoundingClientRect();
      this.mousePosition = {
        x: e.clientX - svgRect.left,
        y: e.clientY - svgRect.top
      };

      if (this.isDrawingEdge) {
        this.updateDrawingEdge();
      }
    },

    handleNodeMouseDown(e) {
      // If the click is on a port, don't initiate node dragging
      if (e.target.closest('.port')) return;
      
      const node = e.target.closest('.node');
      if (!node || e.button !== 0) return;

      this.isDragging = true;
      this.draggedNode = node;
      
      const svgRect = this.svg.getBoundingClientRect();
      this.dragStartPosition = {
        x: e.clientX - svgRect.left,
        y: e.clientY - svgRect.top
      };

      // Notify server about drag start
      this.pushEvent('mousedown', {
        button: 0,
        clientX: this.dragStartPosition.x,
        clientY: this.dragStartPosition.y,
        node_id: node.dataset.nodeId
      });

      e.preventDefault();
    },

    handleNodeDrag(e) {
      if (!this.isDragging || !this.draggedNode) return;

      const svgRect = this.svg.getBoundingClientRect();
      const currentX = e.clientX - svgRect.left;
      const currentY = e.clientY - svgRect.top;

      // Calculate movement
      const movementX = currentX - this.dragStartPosition.x;
      const movementY = currentY - this.dragStartPosition.y;

      console.log(`NodeCanvas: dragging node to position (${currentX}, ${currentY})`);

      // Notify server about movement
      this.pushEvent('mousemove', {
        clientX: currentX,
        clientY: currentY,
        movementX: movementX,
        movementY: movementY
      });

      // Update edge paths during drag
      this.updateEdgePaths();

      e.preventDefault();
    },

    handleNodeMouseUp(e) {
      if (!this.isDragging) return;

      const nodeId = this.draggedNode ? this.draggedNode.dataset.nodeId : 'unknown';
      console.log(`NodeCanvas: finished dragging node ${nodeId}`);

      this.isDragging = false;
      this.draggedNode = null;
      this.dragStartPosition = { x: 0, y: 0 };

      // Notify server about drag end
      this.pushEvent('mouseup', {});

      // Update edge paths after drag is complete
      this.updateEdgePaths();

      e.preventDefault();
    },

    handleKeyDown(e) {
      if (e.key === 'Escape' && this.isDragging) {
        this.pushEvent('keydown', { key: 'Escape' });
        this.isDragging = false;
        this.draggedNode = null;
        this.dragStartPosition = { x: 0, y: 0 };
      }
    },

    setupPortListeners() {
      // Handle port interactions for edge creation
      this.el.addEventListener('mousedown', (e) => {
        const port = e.target.closest('.port');
        if (!port) return;

        const node = port.closest('.node');
        if (!node) return;

        // Stop event propagation to prevent node dragging
        e.stopPropagation();
        
        console.log('Port mousedown detected:', {
          nodeId: node.dataset.nodeId,
          isOutput: port.classList.contains('output'),
          isInput: port.classList.contains('input'),
          portElement: port,
          nodeElement: node
        });

        // Get the port's position in SVG coordinates
        const nodeTransform = node.getAttribute('transform');
        const nodePos = this.parseTransform(nodeTransform);
        
        // Calculate port position based on its cx/cy attributes and node position
        const portCx = parseFloat(port.getAttribute('cx'));
        const portCy = parseFloat(port.getAttribute('cy'));
        const portX = nodePos.x + portCx;
        const portY = nodePos.y + portCy;
        
        console.log('Port position:', { portX, portY });

        this.isDrawingEdge = true;
        this.startPort = {
          nodeId: node.dataset.nodeId,
          isOutput: port.classList.contains('output'),
          x: portX,
          y: portY
        };

        // Notify server that we started drawing an edge
        this.pushEvent('edge_started', {
          source_id: this.startPort.nodeId
        });
        
        console.log('Edge drawing started:', this.isDrawingEdge, this.startPort);
      });

      this.el.addEventListener('mouseup', (e) => {
        console.log('Mouseup detected, isDrawingEdge:', this.isDrawingEdge);
        if (!this.isDrawingEdge) return;

        const port = e.target.closest('.port');
        console.log('Target port:', port);
        
        if (port) {
          // Stop event propagation to prevent node dragging
          e.stopPropagation();
          
          const node = port.closest('.node');
          console.log('Target node:', node);
          
          if (node) {
            const endNodeId = node.dataset.nodeId;
            const isInput = port.classList.contains('input');

            console.log('Edge completion candidate:', {
              sourceId: this.startPort.nodeId,
              targetId: endNodeId,
              sourceIsOutput: this.startPort.isOutput,
              targetIsInput: isInput
            });

            // Only connect if we're going from output to input
            if (this.startPort.isOutput && isInput) {
              console.log('Edge completed successfully');
              this.pushEvent('edge_completed', {
                target_id: endNodeId
              });
            } else {
              console.log('Edge not completed: port type mismatch');
            }
          }
        }

        this.isDrawingEdge = false;
        this.startPort = null;
        this.pushEvent('edge_cancelled', {});
        console.log('Edge drawing cancelled/completed');
      });
    },

    updateDrawingEdge() {
      if (!this.isDrawingEdge || !this.startPort) return;

      const drawingEdge = this.el.querySelector('#drawing-edge');
      if (!drawingEdge) {
        console.error('Drawing edge element not found');
        return;
      }

      // Use the exact port position instead of calculating from the node
      const startX = this.startPort.x;
      const startY = this.startPort.y;
      
      // Create a path from the port to the current mouse position
      const path = `M ${startX} ${startY} 
                    C ${startX + 50} ${startY},
                      ${this.mousePosition.x - 50} ${this.mousePosition.y},
                      ${this.mousePosition.x} ${this.mousePosition.y}`;

      drawingEdge.setAttribute('d', path);
      console.log('Drawing edge updated');
    },

    updateEdgePaths() {
      const edges = this.el.querySelectorAll('.edge-path');
      edges.forEach(edge => {
        const sourceId = edge.dataset.source;
        const targetId = edge.dataset.target;
        
        if (!sourceId || !targetId) return;
        
        const path = this.calculateEdgePath(
          { nodeId: sourceId },
          { nodeId: targetId },
          true
        );
        
        edge.setAttribute('d', path);
      });
    },

    calculateEdgePath(start, end, isOutput) {
      // Calculate port positions based on node positions
      const sourceNode = this.el.querySelector(`[data-node-id="${start.nodeId || start.x}"]`);
      const targetNode = this.el.querySelector(`[data-node-id="${end.nodeId || end.x}"]`);
      
      let startX, startY, endX, endY;
      
      if (sourceNode && targetNode) {
        // For existing edges between nodes
        const sourcePos = this.parseTransform(sourceNode.getAttribute('transform'));
        const targetPos = this.parseTransform(targetNode.getAttribute('transform'));
        
        // Add the port offset to the node position
        startX = sourcePos.x + 200; // Output port is on the right side
        startY = sourcePos.y + 50;  // Ports are vertically centered
        endX = targetPos.x;         // Input port is on the left side
        endY = targetPos.y + 50;    // Ports are vertically centered
      } else {
        // For drawing edges or other cases
        startX = start.x !== undefined ? start.x : start.x + (isOutput ? 200 : 0);
        startY = start.y !== undefined ? start.y : start.y + 50;
        endX = end.x !== undefined ? end.x : end.x + (isOutput ? 0 : 200);
        endY = end.y !== undefined ? end.y : end.y + 50;
      }

      // Calculate control points for the curve
      const dx = Math.abs(endX - startX);
      const controlOffset = Math.min(dx * 0.5, 150);

      // Create a smooth curve using cubic bezier
      return `M ${startX} ${startY} 
              C ${startX + controlOffset} ${startY},
                ${endX - controlOffset} ${endY},
                ${endX} ${endY}`;
    },

    parseTransform(transform) {
      if (!transform) return { x: 0, y: 0 };
      const match = transform.match(/translate\(([^,]+),([^)]+)\)/);
      if (!match) return { x: 0, y: 0 };
      return {
        x: parseFloat(match[1]),
        y: parseFloat(match[2])
      };
    },

    getInitialNodeData(type) {
      switch (type) {
        case 'agent':
          return {
            label: 'New Agent',
            description: 'Agent description',
            goal: 'Agent goal',
            components: []
          };
        case 'prism':
          return {
            label: 'New Prism',
            description: 'Prism description',
            input_schema: null,
            output_schema: null
          };
        case 'lens':
          return {
            label: 'New Lens',
            description: 'Lens description',
            url: '',
            method: 'GET',
            schema: null
          };
        case 'beam':
          return {
            label: 'New Beam',
            description: 'Beam description',
            input_schema: null,
            output_schema: null
          };
        default:
          return { label: 'New Node' };
      }
    }
  }
};

export default NodeEditorHooks; 