import Foundation
import Combine

final class DynamicComponentStorage<T : Component> {
    
    var component : T? = nil
    
    let didCreate = SignalEmitter()
    let didDestroy = SignalEmitter()
    
    fileprivate var cancellables = Set<AnyCancellable>()

    var isCreated : Bool {
        component != nil
    }
    
    deinit {
        destroy()
        
        ObservationBag.shared.remove(for: didCreate.id)
        ObservationBag.shared.remove(for: didDestroy.id)
    }
    
    @discardableResult
    func create(allocator : () -> T) -> UUID {
        let monitoringId = ObservationBag.shared.beginMonitoring{ cancellable in
            self.cancellables.insert(cancellable)
        }
    
        let component = allocator().bind()
        self.component = component

        ObservationBag.shared.endMonitoring(key: monitoringId)
        
        return component.id
    }
    
    @discardableResult
    func destroy() -> UUID? {
        guard let id = component?.id else {
            return nil
        }
    
        let enumerator = RouterStorage.storage(forComponent: id)?.registered.objectEnumerator()
        
        while let router = enumerator?.nextObject() as? Router {
            router.target = nil
            router.routes.removeAll()
            
            ObservationBag.shared.remove(for: router.didPush.id)
            ObservationBag.shared.remove(for: router.didPop.id)
            ObservationBag.shared.remove(for: router.didReplace.id)
        }
        
        ObservationBag.shared.remove(forOwner: id)
     
        self.component = nil
     
        DispatchQueue.main.async { [weak self] in
            self?.cancellables.forEach {
                $0.cancel()
            }
            
            self?.cancellables.removeAll()
        }
        
        return id
    }
}
