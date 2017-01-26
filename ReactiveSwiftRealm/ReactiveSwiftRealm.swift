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

enum ReactiveSwiftRealmError:Error{
    case wrongThread
    case deletedInAnotherThread
    case alreadyExists
}

enum ReactiveSwiftRealmThread:Error{
    case main
    case background
}

// Realm save closure
public typealias UpdateClosure<T> = (_ object:T) -> ()

private func objectAlreadyExists<T:Object>(realm:Realm,object:T)->Bool{
    if let primaryKey = type(of: object).primaryKey(),
        let _ = realm.object(ofType: type(of: object), forPrimaryKey: object.value(forKey: primaryKey)) {
        return true
    }
    return false
}

extension ReactiveRealmOperable where Self:Object{
    
    func add(realm:Realm? = nil,update:Bool = false,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                if !update && objectAlreadyExists(realm: threadRealm, object: self){
                    observer.send(error: .alreadyExists)
                    return
                }
                threadRealm.beginWrite()
                threadRealm.add(self, update: update)
                try! threadRealm.commitWrite()
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
                        threadRealm.beginWrite()
                        threadRealm.add(object, update: update)
                        try! threadRealm.commitWrite()
                        
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
                        threadRealm.beginWrite()
                        threadRealm.add(object, update: update)
                        try! threadRealm.commitWrite()
                        
                        DispatchQueue.main.async {
                            observer.send(value: ())
                            observer.sendCompleted()
                        }
                    }
                }
            }
            
        }
    }
    
    func update(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main,operation:@escaping UpdateClosure<Self>)->SignalProducer<(),ReactiveSwiftRealmError>{
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
    
    func delete(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                threadRealm.beginWrite()
                threadRealm.delete(self)
                try! threadRealm.commitWrite()
                observer.send(value: ())
                observer.sendCompleted()
            case.background:
                if self.realm == nil{
                    let object = self
                    DispatchQueue(label: "background").async {
                        let threadRealm = try! Realm()
                        threadRealm.beginWrite()
                        threadRealm.delete(object)
                        try! threadRealm.commitWrite()
                        
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
                        threadRealm.beginWrite()
                        threadRealm.delete(object)
                        try! threadRealm.commitWrite()
                        
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


extension Array where Element:Object{
    func add(realm:Realm? = nil,update:Bool = false,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                threadRealm.beginWrite()
                threadRealm.add(self, update: update)
                try! threadRealm.commitWrite()
                observer.send(value: ())
                observer.sendCompleted()
            case.background:
                let notStoredReferences = self.filter{$0.realm == nil}
                DispatchQueue(label: "background").async {
                    let threadRealm = try! Realm()
                    threadRealm.beginWrite()
                    threadRealm.add(notStoredReferences, update: update)
                    try! threadRealm.commitWrite()
                    
                    DispatchQueue.main.async {
                        observer.send(value: ())
                        observer.sendCompleted()
                    }
                }
 
            }
            
        }
    }
    
    func update(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main,operation:@escaping UpdateClosure<Array.Element>)->SignalProducer<(),ReactiveSwiftRealmError>{
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
    
    func delete(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm = try! realm ?? Realm()
                threadRealm.beginWrite()
                threadRealm.delete(self)
                try! threadRealm.commitWrite()
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
                    threadRealm.beginWrite()
                    threadRealm.delete(safeObjects)
                    try! threadRealm.commitWrite()
                    
                    DispatchQueue.main.async {
                        observer.send(value: ())
                        observer.sendCompleted()
                    }
                }
            }
            
        }
    }
}

extension ReactiveRealmQueryable where Self:Object{
    static func findBy(key:Any,realm:Realm = try! Realm()) -> SignalProducer<Self?,ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            if !Thread.isMainThread {
                observer.send(error: .wrongThread)
                return
            }
            observer.send(value: realm.object(ofType: Self.self, forPrimaryKey: key))
        }
        
    }
    
    static func findBy(query:String,realm:Realm = try! Realm()) -> SignalProducer<Results<Self>,ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            if !Thread.isMainThread {
                observer.send(error: .wrongThread)
                return
            }
            observer.send(value: realm.objects(Self.self).filter(query))
        }
    }
}

extension SignalProducerProtocol where Value: NotificationEmitter, Error == ReactiveSwiftRealmError {
    func reactive() -> SignalProducer<(value:Self.Value,changes:RealmChangeset?), ReactiveSwiftRealmError> {
        return producer.flatMap(.latest) {results -> SignalProducer<(value:Self.Value,changes:RealmChangeset?), ReactiveSwiftRealmError> in
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

extension SignalProducerProtocol where Value:SortableRealmResults, Error == ReactiveSwiftRealmError{
    /**
     Sorts the signal producer of Results<T> using a key an the ascending value
     :param: key key the results will be sorted by
     :param: ascending true if the results sort order is ascending
     :returns: sorted SignalProducer
     */
    func sorted(key: String, ascending: Bool = true) -> SignalProducer<Self.Value, ReactiveSwiftRealmError> {
        return producer.flatMap(.latest) { results in
            return SignalProducer(value:results.sorted(byProperty: key, ascending: ascending) as Self.Value) as SignalProducer<Self.Value, ReactiveSwiftRealmError>
        }
    }
}


// - MARK: Protocol helpers

extension Object:ReactiveRealmQueryable{}

protocol ReactiveRealmQueryable{}


extension Object:ReactiveRealmOperable{}

protocol ReactiveRealmOperable:ThreadConfined{}


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




