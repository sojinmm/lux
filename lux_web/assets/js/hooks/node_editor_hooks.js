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
      console.log(`NodeDraggable hook mounted for node: ${this.el.dataset.nodeId}`);
      
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
        console.log(`NodeDraggable: pushing mousedown event to canvas with node_id: ${nodeId}, clientX: ${mouseX}, clientY: ${mouseY}`);
        
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
      console.log("NodeCanvas hook mounted");
      
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
      const node = e.target.closest('.node');
      if (!node || e.button !== 0) return;

      this.isDragging = true;
      this.draggedNode = node;
      
      const svgRect = this.svg.getBoundingClientRect();
      this.dragStartPosition = {
        x: e.clientX - svgRect.left,
        y: e.clientY - svgRect.top
      };

      console.log(`NodeCanvas: handleNodeMouseDown - node: ${node.dataset.nodeId}, position: (${this.dragStartPosition.x}, ${this.dragStartPosition.y})`);
      console.log(`NodeCanvas: pushing mousedown event with node_id: ${node.dataset.nodeId}, clientX: ${this.dragStartPosition.x}, clientY: ${this.dragStartPosition.y}`);

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

      console.log(`NodeCanvas: dragging node ${this.draggedNode.dataset.nodeId} to position (${currentX}, ${currentY}), movement: (${movementX}, ${movementY})`);
      console.log(`NodeCanvas: pushing mousemove event with clientX: ${currentX}, clientY: ${currentY}, movementX: ${movementX}, movementY: ${movementY}`);

      // Notify server about movement
      this.pushEvent('mousemove', {
        clientX: currentX,
        clientY: currentY,
        movementX: movementX,
        movementY: movementY
      });

      e.preventDefault();
    },

    handleNodeMouseUp(e) {
      if (!this.isDragging) return;

      const nodeId = this.draggedNode ? this.draggedNode.dataset.nodeId : 'unknown';
      console.log(`NodeCanvas: finished dragging node ${nodeId}`);
      console.log(`NodeCanvas: pushing mouseup event`);

      this.isDragging = false;
      this.draggedNode = null;
      this.dragStartPosition = { x: 0, y: 0 };

      // Notify server about drag end
      this.pushEvent('mouseup', {});

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

        this.isDrawingEdge = true;
        this.startPort = {
          nodeId: node.dataset.nodeId,
          isOutput: port.classList.contains('output')
        };

        // Notify server that we started drawing an edge
        this.pushEvent('edge_started', {
          source_id: this.startPort.nodeId
        });
      });

      this.el.addEventListener('mouseup', (e) => {
        if (!this.isDrawingEdge) return;

        const port = e.target.closest('.port');
        if (port) {
          const node = port.closest('.node');
          if (node) {
            const endNodeId = node.dataset.nodeId;
            const isInput = port.classList.contains('input');

            // Only connect if we're going from output to input
            if (this.startPort.isOutput && isInput) {
              this.pushEvent('edge_completed', {
                target_id: endNodeId
              });
            }
          }
        }

        this.isDrawingEdge = false;
        this.startPort = null;
        this.pushEvent('edge_cancelled', {});
      });
    },

    updateDrawingEdge() {
      if (!this.isDrawingEdge || !this.startPort) return;

      const drawingEdge = this.el.querySelector('#drawing-edge');
      if (!drawingEdge) return;

      const startNode = this.el.querySelector(`[data-node-id="${this.startPort.nodeId}"]`);
      if (!startNode) return;

      const startNodeTransform = startNode.getAttribute('transform');
      const startPos = this.parseTransform(startNodeTransform);

      const path = this.calculateEdgePath(
        startPos,
        this.mousePosition,
        this.startPort.isOutput
      );

      drawingEdge.setAttribute('d', path);
    },

    updateEdgePaths() {
      const edges = this.el.querySelectorAll('.edge-path');
      edges.forEach(edge => {
        const sourceNode = this.el.querySelector(`[data-node-id="${edge.dataset.source}"]`);
        const targetNode = this.el.querySelector(`[data-node-id="${edge.dataset.target}"]`);

        if (!sourceNode || !targetNode) return;

        const sourceTransform = sourceNode.getAttribute('transform');
        const targetTransform = targetNode.getAttribute('transform');

        const sourcePos = this.parseTransform(sourceTransform);
        const targetPos = this.parseTransform(targetTransform);

        const path = this.calculateEdgePath(sourcePos, targetPos, true);
        edge.setAttribute('d', path);
      });
    },

    calculateEdgePath(start, end, isOutput) {
      // Add the port offset to the node position
      const startX = start.x + (isOutput ? 200 : 0);
      const startY = start.y + 50;
      const endX = end.x + (isOutput ? 0 : 200);
      const endY = end.y + 50;

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