//
//  ReactiveSwiftRealm.swift
//  ReactiveSwiftRealm
//
//  Created by David Collado on 18/1/17.
//  Copyright © 2017 David Collado. All rights reserved.
//

import ReactiveSwift
import Result
import RealmSwift

public enum ReactiveSwiftRealmError:Error{
    case wrongThread
    case deletedInAnotherThread
    case alreadyExists
}

public enum ReactiveSwiftRealmThread:Error{
    case main
    case background
}

// Realm save closure
public typealias UpdateClosure<T> = (_ object:T) -> ()

// - MARK: Helpers

private func objectAlreadyExists(realm:Realm,object:Object)->Bool{
  if let primaryKey = type(of: object).primaryKey(),
    let _ = realm.object(ofType: type(of: object), forPrimaryKey: object.value(forKey: primaryKey)) {
    return true
  }
  return false
}

private func addOperation(realm:Realm,object:Object,update:Bool){
    realm.beginWrite()
    realm.add(object, update: update)
    try! realm.commitWrite()
}

private func addOperation(realm:Realm,objects:[Object],update:Bool){
    realm.beginWrite()
    realm.add(objects, update: update)
    try! realm.commitWrite()
}

private func deleteOperation(realm:Realm,object:Object){
    realm.beginWrite()
    realm.delete(object)
    try! realm.commitWrite()
}

private func deleteOperation(realm:Realm,objects:[Object]){
    realm.beginWrite()
    realm.delete(objects)
    try! realm.commitWrite()
}

public extension ReactiveRealmOperable where Self:Object{
    
    public func add(realm:Realm? = nil,update:Bool = false,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                if !update && objectAlreadyExists(realm: threadRealm, object: self){
                    observer.send(error: .alreadyExists)
                    return
                }
                addOperation(realm:threadRealm,object:self,update:update)
                observer.send(value: ())
                observer.sendCompleted()
            case.background:
                if self.realm == nil{
                    let object = self
                    DispatchQueue(label: "background").async {
                        let threadRealm = try! Realm()
                        if !update && objectAlreadyExists(realm: threadRealm, object: object){
                            observer.send(error: .alreadyExists)
                            return
                        }
                        
                        addOperation(realm:threadRealm,object:object,update:update)
                        
                        DispatchQueue.main.async {
                            observer.send(value: ())
                            observer.sendCompleted()
                        }
                    }
                }else{
                    let objectRef = ThreadSafeReference(to: self)
                    DispatchQueue(label: "background").async {
                        let threadRealm = try! Realm()
                        guard let object = threadRealm.resolve(objectRef) else {
                            observer.send(error: .deletedInAnotherThread)
                            return
                        }
                        if !update && objectAlreadyExists(realm: threadRealm, object: object){
                            observer.send(error: .alreadyExists)
                            return
                        }
                        
                        addOperation(realm:threadRealm,object:object,update:update)
                        
                        DispatchQueue.main.async {
                            observer.send(value: ())
                            observer.sendCompleted()
                        }
                    }
                }
            }
            
        }
    }
    
    public func update(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main,operation:@escaping UpdateClosure<Self>)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            if !Thread.isMainThread{
                observer.send(error: .wrongThread)
                return
            }
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                threadRealm.beginWrite()
                operation(self)
                try! threadRealm.commitWrite()
                observer.send(value: ())
                observer.sendCompleted()
            case .background:
                let objectRef = ThreadSafeReference(to: self)
                DispatchQueue(label: "background").async {
                    let threadRealm = try! Realm()
                    
                    guard let object = threadRealm.resolve(objectRef) else {
                        observer.send(error: .deletedInAnotherThread)
                        return
                    }
                    threadRealm.beginWrite()
                    operation(object)
                    try! threadRealm.commitWrite()
                    DispatchQueue.main.async {
                        observer.send(value: ())
                        observer.sendCompleted()
                    }
                }
            }
            
        }
    }
    
    public func delete(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                deleteOperation(realm: threadRealm, object: self)
                observer.send(value: ())
                observer.sendCompleted()
            case.background:
                if self.realm == nil{
                    let object = self
                    DispatchQueue(label: "background").async {
                        let threadRealm = try! Realm()
                        deleteOperation(realm: threadRealm, object: object)
                        
                        DispatchQueue.main.async {
                            observer.send(value: ())
                            observer.sendCompleted()
                        }
                    }
                }else{
                    let objectRef = ThreadSafeReference(to: self)
                    DispatchQueue(label: "background").async {
                        let threadRealm = try! Realm()
                        guard let object = threadRealm.resolve(objectRef) else {
                            observer.send(error: .deletedInAnotherThread)
                            return
                        }
                        deleteOperation(realm: threadRealm, object: object)
                        
                        DispatchQueue.main.async {
                            observer.send(value: ())
                            observer.sendCompleted()
                        }
                    }
                }
            }
            
        }
    }
 
}


public extension Array where Element:Object{
    public func add(realm:Realm? = nil,update:Bool = false,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                addOperation(realm: threadRealm, objects: self, update: update)
                observer.send(value: ())
                observer.sendCompleted()
            case.background:
                let notStoredReferences = self.filter{$0.realm == nil}
                DispatchQueue(label: "background").async {
                    let threadRealm = try! Realm()
                    addOperation(realm: threadRealm, objects: notStoredReferences, update: update)
                    
                    DispatchQueue.main.async {
                        observer.send(value: ())
                        observer.sendCompleted()
                    }
                }
 
            }
            
        }
    }
    
    public func update(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main,operation:@escaping UpdateClosure<Array.Element>)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            if !Thread.isMainThread{
                observer.send(error: .wrongThread)
                return
            }
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                threadRealm.beginWrite()
                for object in self{
                    operation(object)
                }
                try! threadRealm.commitWrite()
                observer.send(value: ())
                observer.sendCompleted()
            case .background:
                let safeReferences = self.filter{$0.realm != nil}.map{ThreadSafeReference(to: $0)}
                DispatchQueue(label: "background").async {
                    let threadRealm = try! Realm()
                    let safeObjects = safeReferences.flatMap({ safeObject in
                        return threadRealm.resolve(safeObject)
                    })
                    if safeObjects.count != self.count{
                        observer.send(error: .deletedInAnotherThread)
                        return
                    }
                    threadRealm.beginWrite()
                    for object in safeObjects{
                        operation(object)
                    }
                    try! threadRealm.commitWrite()
                    
                    DispatchQueue.main.async {
                        observer.send(value: ())
                        observer.sendCompleted()
                    }
                }
            }
            
        }
    }
    
    public func delete(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                deleteOperation(realm: threadRealm, objects: self)
                observer.send(value: ())
                observer.sendCompleted()
            case.background:
                let safeReferences = self.filter{$0.realm != nil}.map{ThreadSafeReference(to: $0)}
                DispatchQueue(label: "background").async {
                    let threadRealm = try! Realm()
                    let safeObjects = safeReferences.flatMap({ safeObject in
                        return threadRealm.resolve(safeObject)
                    })
                    if safeObjects.count != self.count{
                        observer.send(error: .deletedInAnotherThread)
                        return
                    }
                    
                    deleteOperation(realm: threadRealm, objects: safeObjects)
                    
                    DispatchQueue.main.async {
                        observer.send(value: ())
                        observer.sendCompleted()
                    }
                }
            }
            
        }
    }
}

public extension ReactiveRealmQueryable where Self:Object{
    public static func findBy(key:Any,realm:Realm = try! Realm()) -> SignalProducer<Self?,ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            if !Thread.isMainThread {
                observer.send(error: .wrongThread)
                return
            }
            observer.send(value: realm.object(ofType: Self.self, forPrimaryKey: key))
        }
        
    }
    
    public static func findBy(query:String,realm:Realm = try! Realm()) -> SignalProducer<Results<Self>,ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            if !Thread.isMainThread {
                observer.send(error: .wrongThread)
                return
            }
            observer.send(value: realm.objects(Self.self).filter(query))
        }
    }
  
  public static func findAll(realm:Realm = try! Realm()) -> SignalProducer<Results<Self>,ReactiveSwiftRealmError>{
    return SignalProducer{ observer,_ in
      if !Thread.isMainThread {
        observer.send(error: .wrongThread)
        return
      }
      observer.send(value: realm.objects(Self.self))
    }
  }
}

public extension SignalProducerProtocol where Value: NotificationEmitter, Error == ReactiveSwiftRealmError {
    
    /**
     Transform Results<T> into a reactive source
     :returns: signal containing updated values and optional RealmChangeset when changed
     */
    
    public typealias RealmReactiveResults = (value:Self.Value,changes:RealmChangeset?)
    
    public  func reactive() -> SignalProducer<RealmReactiveResults, ReactiveSwiftRealmError> {
        return producer.flatMap(.latest) {results -> SignalProducer<RealmReactiveResults, ReactiveSwiftRealmError> in
            return SignalProducer { observer,disposable in
                let notificationToken = results.addNotificationBlock { (changes: RealmCollectionChange) in
                    switch changes {
                    case .initial:
                        observer.send(value: (value: results, changes: RealmChangeset(deleted: [], inserted: (0..<results.count).map {$0}, updated: [])))
                        break
                    case .update(let values, let deletes, let inserts, let updates):
                        observer.send(value: (value: values, changes: RealmChangeset(deleted: deletes, inserted: inserts, updated: updates)))
                        break
                    case .error(let error):
                        // An error occurred while opening the Realm file on the background worker thread
                        fatalError("\(error)")
                        break
                    }
                }
                disposable.add {
                    notificationToken.stop()
                    observer.sendCompleted()
                }
            }
        }
    }
}

public  extension SignalProducerProtocol where Value:SortableRealmResults, Error == ReactiveSwiftRealmError{
    /**
     Sorts the signal producer of Results<T> using a key an the ascending value
     :param: key key the results will be sorted by
     :param: ascending true if the results sort order is ascending
     :returns: sorted SignalProducer
     */
    public  func sorted(key: String, ascending: Bool = true) -> SignalProducer<Self.Value, ReactiveSwiftRealmError> {
        return producer.flatMap(.latest) { results in
            return SignalProducer(value:results.sorted(byProperty: key, ascending: ascending) as Self.Value) as SignalProducer<Self.Value, ReactiveSwiftRealmError>
        }
    }
}


// - MARK: Protocol helpers

extension Object:ReactiveRealmQueryable{}
public  protocol ReactiveRealmQueryable{}

extension Object:ReactiveRealmOperable{}
public  protocol ReactiveRealmOperable:ThreadConfined{}


/**
 `NotificationEmitter` is a faux protocol to allow for Realm's collections to be handled in a generic way.
 
 All collections already include a `addNotificationBlock(_:)` method - making them conform to `NotificationEmitter` just makes it easier to add Reactive methods to them.
 */

public protocol NotificationEmitter {
    
    /**
     Returns a `NotificationToken`, which while retained enables change notifications for the current collection.
     
     - returns: `NotificationToken` - retain this value to keep notifications being emitted for the current collection.
     */
    func addNotificationBlock(_ block: @escaping (RealmSwift.RealmCollectionChange<Self>) -> Swift.Void) -> NotificationToken
    
    var count:Int{get}
}


 extension Results:NotificationEmitter{}

/**
 `RealmChangeset` is a struct that contains the data about a single realm change set.
 
 It includes the insertions, modifications, and deletions indexes in the data set that the current notification is about.
 */
public struct RealmChangeset {
    /// the indexes in the collection that were deleted
    public let deleted: [Int]
    
    /// the indexes in the collection that were inserted
    public let inserted: [Int]
    
    /// the indexes in the collection that were modified
    public let updated: [Int]
    
    public init(deleted: [Int], inserted: [Int], updated: [Int]) {
        self.deleted = deleted
        self.inserted = inserted
        self.updated = updated
    }
}

public protocol SortableRealmResults {
    
    /**
     Returns a `Results<T>` sorted
     
     - returns: `Results<T>`
     */
    
    func sorted(byProperty property: String, ascending: Bool) -> Self
}


extension Results:SortableRealmResults{}




