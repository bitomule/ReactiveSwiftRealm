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
}

enum ReactiveSwiftRealmThread:Error{
    case main
    case background
}

// Realm save closure
public typealias UpdateClosure<T> = (_ object:T) -> ()

extension Object{
    
    func add(realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            switch thread{
            case .main:
                let threadRealm:Realm
                if let realm = realm{
                    threadRealm = realm
                }else{
                    threadRealm = try! Realm()
                }
                threadRealm.beginWrite()
                threadRealm.add(self)
                try! threadRealm.commitWrite()
                observer.send(value: ())
                observer.sendCompleted()
            case.background:
                if self.realm == nil{
                    let object = self
                    DispatchQueue(label: "background").async {
                        let threadRealm = try! Realm()
                        threadRealm.beginWrite()
                        threadRealm.add(object)
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
                        threadRealm.add(object)
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
    
    func update<T:Object>(type:T.Type,realm:Realm? = nil,thread:ReactiveSwiftRealmThread = .main,operation:@escaping UpdateClosure<T>)->SignalProducer<(),ReactiveSwiftRealmError>{
        return SignalProducer{ observer,_ in
            if !Thread.isMainThread{
                observer.send(error: .wrongThread)
                return
            }
            switch thread{
            case .main:
                let threadRealm:Realm
                if let realm = realm{
                    threadRealm = realm
                }else{
                    threadRealm = try! Realm()
                }
                threadRealm.beginWrite()
                operation(self as! T)
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
                    operation(object as! T)
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
                let threadRealm:Realm
                if let realm = realm{
                    threadRealm = realm
                }else{
                    threadRealm = try! Realm()
                }
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
