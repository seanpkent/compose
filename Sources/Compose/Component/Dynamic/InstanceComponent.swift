import Foundation
import SwiftUI

protocol AnyInstanceComponent {
    
    var instanceId : UUID { get }
    
}

@dynamicMemberLookup
public struct InstanceComponent<T : Component> : Component, AnyInstanceComponent {
    
    public let id = UUID()
    
    public var type: Component.Type {
        T.self
    }
    
    public var observers: Void {
        None
    }
    
    public var didCreate : ValueEmitter<UUID> {
        storage.didCreate
    }
    
    public var didDestroy : ValueEmitter<UUID> {
        storage.didDestroy
    }
    
    public var component : T? {
        storage.components[id]
    }
    
    public var isEmpty : Bool {
        storage.components.isEmpty
    }

    public var instanceId : UUID {
        storage.currentId ?? UUID()
    }
    
    let storage = InstanceComponentStorage<T>()

    public init() {
        // Intentionally left blank
    }

}

extension InstanceComponent {
    
    public func add(_ allocator : () -> T) {
        let id = storage.create(allocator: allocator)
        didCreate.send(id)
        
        Introspection.shared.updateDescriptor(for: self.id) {
            $0?.add(component: id)
        }

        Introspection.shared.updateDescriptor(for: id) {
            $0?.lifecycle = .instance
        }
    }
    
    public subscript<V>(dynamicMember keyPath : KeyPath<T, V>) -> V {
        guard let id = storage.currentId, storage.components[id] != nil else {
            fatalError("[InstanceComponent] Attempting to get property of \(T.self) without creating it first.")
        }
        
        return storage.components[id]![keyPath: keyPath]
    }
    
}

extension InstanceComponent : View {
    
    public var body: some View {
        guard let id = storage.currentId, let component = storage.components[id] else {
            fatalError("[InstanceComponent] Component \(T.self) must be set before accessing it.")
        }
        
        return component.view
            .onAppear {
                Introspection.shared.updateDescriptor(for: self.id) {
                    $0?.isVisible = storage.components.count > 0
                }
            }
            .onDisappear {
                storage.destroy(id: id)
                didDestroy.send(id)
                
                Introspection.shared.updateDescriptor(for: self.id) {
                    $0?.isVisible = storage.components.count == 0
                    $0?.remove(component: id)
                }
            }
    }
    
}
