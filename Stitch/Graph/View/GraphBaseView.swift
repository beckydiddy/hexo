//
//  GraphBase.swift
//  prototype
//
//  Created by Christian J Clampitt on 1/26/22.
//

import SwiftUI
import StitchSchemaKit

// Grid lines, cursor, selection box, patch and layer nodes
struct GraphBaseView: View {
    
    static let coordinateNamespace = "GRAPHBASEVIEW_NAMESPACE"
    
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets: SafeAreaInsets
    
    @State private var spaceHeld = false

    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel
    
    @MainActor
    var graph: GraphState {
        self.document.visibleGraph
    }

    var body: some View {
        // Our screen device measurements ignore the safe area,
        // so our touch-responsive interfaces must ignore them to.

        nodesAndCursor
            .onAppear {
                
                // Note: keep around for helpful printing of the structured outputs schema
                // log("STRUCTURED OUTPUTS: \n \(structuredOutputsSchemaAsString())")
                
                //                // NOTE: better for this logic to live here than in the StitchApp onAppear; so that it can be triggered multiple times without having to restart the app
                //                do {
                ////                        // For 4o
                ////                    try StitchAITrainingData.validateTrainingData(from: "gpt4o-fine-tuning-dataset")
                ////
                ////                        // For o4-mini
                ////                        try StitchAIReasoningTrainingData.validateTrainingData(from: "gpt_o4_mini_reasoner_train")
                ////                        try StitchAIReasoningTrainingData.validateTrainingData(from: "gpt_o4_mini_reasoner_valid")
                //
                //                } catch {
                //                    print("StitchAITrainingData error: \(error)")
                //                }
                
                #if targetEnvironment(macCatalyst)
                if self.spaceHeld || document.keypressState.isSpacePressed {
                    NSCursor.openHand.push()
                }
                #endif
                dispatch(ColorSchemeReceived(colorScheme: colorScheme))
                dispatch(SafeAreaInsetsReceived(insets: safeAreaInsets))
            }
            .onChange(of: colorScheme) { _, color in
                //                log("GraphBaseView: onChange of ColorScheme")
                dispatch(ColorSchemeReceived(colorScheme: color))
            }
            .onChange(of: safeAreaInsets) { _, insets in
                //                log("GraphBaseView: onChange of safeAreaInsets")
                dispatch(SafeAreaInsetsReceived(insets: insets))
            }

        #if targetEnvironment(macCatalyst)
            .modifier(GraphHoverViewModifier(spaceHeld: self.$spaceHeld,
                                             document: document))
        #endif
    }

    @ViewBuilder @MainActor
    var nodesView: some View {
        NodesView(document: document,
                  graph: graph,
                  groupTraversedToChild: document.groupTraversedToChild)
        .overlay {
            // Show debug mode tip view
            if document.isDebugMode {
                TopLeftCornerView {
                    DebugModePopover()
                }
            }
            
            switch document.llmRecording.modal {
                
            case .editBeforeSubmit:
                TopLeftCornerView {
                    EditBeforeSubmitModalView(document: document, graph: graph)
                }
           
            case .none, .ratingToast, .submitExistingGraphAsTrainingExample, .aiNodePromptEntry:
                // Either not applicable, or handled elsewhere
                EmptyView()
            }
        }
    }
    
    @ViewBuilder @MainActor
    var nodesAndCursor: some View {
        ZStack {

            // To cover top safe area that we don't ignore on iPad and that is gesture-inaccessbile
            Stitch.APP_BACKGROUND_COLOR
                .edgesIgnoringSafeArea(.all)
            
            //#if DEV_DEBUG
            //            // Use `ZStack { ...` instead of `ZStack(alignment: .top) { ...`
            //            // to get in exact screen center.
            //            Circle().fill(.cyan.opacity(0.5))
            //                .frame(width: 60, height: 60)
            //#endif

            nodesView
                          
            // IMPORTANT: applying .inspector outside of this ZStack causes displacement of graph contents when graph zoom != 1
            Circle().fill(Stitch.APP_BACKGROUND_COLOR.opacity(0.001))
                .frame(width: 1, height: 1)
            #if targetEnvironment(macCatalyst)
                .inspector(isPresented: $store.showsLayerInspector) {
                    LayerInspectorView(graph: graph,
                                       document: document)
                }
            #endif
        } // ZStack
        
        .modifier(ActivelyDrawnEdge(graph: graph,
                                    scale: document.graphMovement.zoomData))
        .coordinateSpace(name: Self.coordinateNamespace)
        
        .bottomCenterToast(willShow: document.llmRecording.showRatingToast,
                           config: .init(duration: 15),
                           onExpireAction: { dispatch(AIRatingToastExpired()) },
                           toastContent: { StitchAIRatingToast() })
        
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .local), initial: true) { oldValue, newValue in
                        // log("SIZE READING: GraphBaseView: local frame: newValue: \(newValue)")
                        dispatch(SetDeviceScreenSize(frame: newValue))
                    }
                    .onChange(of: geometry.frame(in: .global), initial: true) { oldValue, newValue in
                        // log("SIZE READING: GraphBaseView: global frame: newValue: \(newValue)")
                        dispatch(SetGraphPosition(graphPosition: newValue.origin))
                        dispatch(SetSidebarWidth(frame: newValue))
                    }
            } // GeometryReader
        } // .background
    }
}

// Uses spacers and V/HStascks to place a view in the top left corner
struct TopLeftCornerView<Content: View>: View {
    
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack {
            HStack {
                content()
                Spacer()
            }
            Spacer()
        }
    }
}


struct GraphHoverViewModifier: ViewModifier {
    @Binding var spaceHeld: Bool
    @Bindable var document: StitchDocumentViewModel
    
    func body(content: Content) -> some View {
        content
#if targetEnvironment(macCatalyst)
            .onHover(perform: { hovering in
                
                // log("GraphBaseView: onHover: hovering: \(hovering)")
                // log("GraphBaseView: onHover: document.keypressState.isSpacePressed: \(document.keypressState.isSpacePressed)")
                // log("GraphBaseView: onHover: self.spaceHeld: \(self.spaceHeld)")
                
                if hovering, self.spaceHeld {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            })
        
            .onChange(of: document.keypressState.isSpacePressed, initial: true) { _, newValue in
                // log("GraphBaseView: onChange: keypressState.isSpacePressed: oldValue: \(oldValue)")
                // log("GraphBaseView: onChange: keypressState.isSpacePressed: newValue: \(newValue)")
                
                if newValue {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
                
                if self.spaceHeld != newValue {
                    self.spaceHeld = newValue
                }
            }
#endif
    }
}

