//
//  NodesOnlyView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/28/23.
//

import SwiftUI
import StitchSchemaKit

struct NodesOnlyView: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    
    var canvasNodes: [CanvasItemViewModel] {
        graph.cachedCanvasItemsAtThisTraversalLevel
    }
    
    var selection: GraphUISelectionState {
        graph.selection
    }
    
    var activeIndex: ActiveIndex {
        document.activeIndex
    }
    
    var focusedGroup: GroupNodeType? {
        document.groupNodeFocused
    }
        
    var body: some View {
        Group {
            // HACK for when no nodes present
            if canvasNodes.isEmpty {
                Rectangle().fill(.clear)
                //                .onAppear() {
                //                    self.refreshCanvasNodes()
                //                }
            }
            
#if DEV_DEBUG
            // scrollView.contentOffset without taking scrollView.zoomScale into account
            Circle().fill(.yellow.opacity(0.95))
                .frame(width: 60, height: 60)
                .position(self.document.graphMovement.localPosition)
                .zIndex(999999999999999)
            
            // scrollView.contentOffset WITH taking scrollView.zoomScale into account
            Circle().fill(.black.opacity(0.95))
                .frame(width: 60, height: 60)
                .position(
                    x: self.document.graphMovement.localPosition.x / self.document.graphMovement.zoomData,
                    y: self.document.graphMovement.localPosition.y / self.document.graphMovement.zoomData
                )
                .zIndex(999999999999999)
#endif
            
            ForEach(canvasNodes) { canvasNode in
                // Note: if/else seems better than opacity modifier, which introduces funkiness with edges (port preference values?) when going in and out of groups;
                // (`.opacity(0)` means we still render the view, and thus anchor preferences?)
                
                if let node = graph.getNode(canvasNode.id.nodeId) {                    
                    NodeView(node: canvasNode,
                             stitch: node,
                             document: document,
                             graph: graph,
                             nodeId: node.id,
                             isSelected: graph.selection.selectedCanvasItems.contains(canvasNode.id),
                             atleastOneCommentBoxSelected: selection.selectedCommentBoxes.count >= 1,
                             activeGroupId: document.groupNodeFocused,
                             canAddInput: node.canChangeInputCounts,
                             canRemoveInput: node.canRemoveInputs,
                             boundsReaderDisabled: false,
                             updateMenuActiveSelectionBounds: false)
                }
            }
        }
        // TODO: why can't we do this logic from `ActiveIndexChangedAction` ?
        .onChange(of: self.activeIndex) {
            
            // Update values when active index changes
            // Perf optimization: only update nodes that are on-screen and at this traversal level
            graph.getNodesAtThisTraversalLevel(groupNodeFocused: self.focusedGroup?.groupNodeId).forEach { node in
                if node.isVisibleInFrame(graph.visibleCanvasIds, graph.selectedSidebarLayers) {
                    node.activeIndexChanged(activeIndex: self.activeIndex)
                }
            }
        }
        // Also do this on `initial: true` ?
        .onChange(of: self.focusedGroup) {
            // Update node locations
            self.graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset = true
        }
    }
}
