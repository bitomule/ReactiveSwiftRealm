//
//  ReactiveSwiftRealmTests.swift
//  ReactiveSwiftRealmTests
//
//  Created by David Collado on 18/1/17.
//  Copyright © 2017 David Collado. All rights reserved.
//

import XCTest
import ReactiveSwift
import Result
import RealmSwift
@testable import ReactiveSwiftRealm

class ReactiveSwiftRealmTests: XCTestCase {
    
    var realm:Realm!
    
    override func setUp() {
        super.setUp()
        Realm.Configuration.defaultConfiguration.inMemoryIdentifier = self.name
        realm = try! Realm()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        realm = nil
    }
    
    func testAddSavesObject(){
        let fakeObject = FakeObject()
        fakeObject.add().start()
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
    }
    
    func testAddSendsSignal(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.add().on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 1)
            expectation.fulfill()
        }).start()
       
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testAddWorksInBackground(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.add(realm: nil, thread: .background).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 1)
            expectation.fulfill()
        }).start()
        
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testAddUpdatesIfObjectWithIdAlreadyExists(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        let fakeId = fakeObject.id
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        let anotherFakeObject = FakeObject()
        anotherFakeObject.id = fakeId
        anotherFakeObject.value = "updatedValue"
        
        anotherFakeObject.add(realm:realm,update:true).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 1)
            XCTAssertEqual(objects.first?.value, "updatedValue")
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testAddUpdatesIfObjectWithIdAlreadyExistsInBackground(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        let fakeId = fakeObject.id
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        let anotherFakeObject = FakeObject()
        anotherFakeObject.id = fakeId
        anotherFakeObject.value = "updatedValue"
        
        anotherFakeObject.add(realm:realm,update:true,thread:.background).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 1)
            XCTAssertEqual(objects.first?.value, "updatedValue")
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testAddSendsErrorIfObjectAlreadyExists(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        let fakeId = fakeObject.id
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        let anotherFakeObject = FakeObject()
        anotherFakeObject.id = fakeId
        anotherFakeObject.value = "updatedValue"
        
        anotherFakeObject.add().on(failed: { error in
            XCTAssertEqual(error, ReactiveSwiftRealmError.alreadyExists)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testUpdateChangesObject(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        fakeObject.update(type: FakeObject.self) { object in
            object.value = "updatedValue"
        }.on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.first?.value, "updatedValue")
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testUpdateSendsErrorWhenNotOnMainThread(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        DispatchQueue.global(qos: .background).async {
            fakeObject.update(type: FakeObject.self) { object in
                object.value = "updatedValue"
                }.on( failed: { error in
                    XCTAssertEqual(error, .wrongThread)
                    expectation.fulfill()
                }).start()
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testUpdateAllowedInBackground(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        fakeObject.update(type: FakeObject.self, realm: nil, thread: .background) { object in
            XCTAssertFalse(Thread.isMainThread)
            object.value = "updatedValue"
        }.on(value: {
                let realm = try! Realm()
                let objects = realm.objects(FakeObject.self)
                XCTAssertEqual(objects.first?.value, "updatedValue")
                expectation.fulfill()
            }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testUpdateInBackgroundSendsSignalInMain(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        fakeObject.update(type: FakeObject.self, realm: nil, thread: .background) { object in
            object.value = "updatedValue"
            }.on(value: {
                XCTAssertTrue(Thread.isMainThread)
                expectation.fulfill()
            }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testDeleteRemovesObject(){
        let fakeObject = FakeObject()
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        fakeObject.delete().start()
        let emptyObjects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 0)
    }
    
    func testDeleteWorksInBackground(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        fakeObject.delete(realm: nil, thread: .background).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 0)
            expectation.fulfill()
        }).start()
        
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testAddSavesArray(){
        let objects = [FakeObject(),FakeObject()]
        objects.add().start()
        let savedObjects = realm.objects(FakeObject.self)
        XCTAssertEqual(savedObjects.count, 2)
    }
    
    func testAddSavesArrayInBackground(){
        let expectation = self.expectation(description: "ready")
        let objects = [FakeObject(),FakeObject()]
        objects.add(realm: nil, thread: .background).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 2)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testAddUpdatesIfArrayWithIdAlreadyExists(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        let fakeObject2 = FakeObject()
        let fakeId1 = fakeObject1.id
        let fakeId2 = fakeObject2.id
        fakeObject1.value = "oldValue"
        fakeObject2.value = "oldValue"
        let fakeObjects = [fakeObject1,fakeObject2]
        try! realm.write {
            realm.add(fakeObjects)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        let anotherFakeObject1 = FakeObject()
        anotherFakeObject1.id = fakeId1
        anotherFakeObject1.value = "updatedValue"
        
        let anotherFakeObject2 = FakeObject()
        anotherFakeObject2.id = fakeId2
        anotherFakeObject2.value = "updatedValue"
        
        let anotherFakeObjects = [anotherFakeObject1,anotherFakeObject2]
        
        anotherFakeObjects.add(realm:realm,update:true).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 2)
            XCTAssertEqual(objects.first?.value, "updatedValue")
            XCTAssertEqual(objects.last?.value, "updatedValue")
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testAddUpdatesIfArrayWithIdAlreadyExistsInBackground(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        let fakeObject2 = FakeObject()
        let fakeId1 = fakeObject1.id
        let fakeId2 = fakeObject2.id
        fakeObject1.value = "oldValue"
        fakeObject2.value = "oldValue"
        let fakeObjects = [fakeObject1,fakeObject2]
        try! realm.write {
            realm.add(fakeObjects)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        let anotherFakeObject1 = FakeObject()
        anotherFakeObject1.id = fakeId1
        anotherFakeObject1.value = "updatedValue"
        
        let anotherFakeObject2 = FakeObject()
        anotherFakeObject2.id = fakeId2
        anotherFakeObject2.value = "updatedValue"
        
        let anotherFakeObjects = [anotherFakeObject1,anotherFakeObject2]
        
        anotherFakeObjects.add(realm:realm,update:true,thread:.background).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 2)
            XCTAssertEqual(objects.first?.value, "updatedValue")
            XCTAssertEqual(objects.last?.value, "updatedValue")
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testUpdateUpdatesArray(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        let fakeObject2 = FakeObject()
        let fakeObjects = [fakeObject1,fakeObject2]
        fakeObject1.value = "oldValue"
        fakeObject2.value = "oldValue"
        try! realm.write {
            realm.add(fakeObjects)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        fakeObjects.update(type: FakeObject.self) { object in
            object.value = "updatedValue"
            }.on(value: {
                let objects = self.realm.objects(FakeObject.self)
                XCTAssertEqual(objects.first?.value, "updatedValue")
                XCTAssertEqual(objects.last?.value, "updatedValue")
                XCTAssertEqual(objects.count, 2)
                expectation.fulfill()
            }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testUpdateUpdatesArrayInBackground(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        let fakeObject2 = FakeObject()
        let fakeObjects = [fakeObject1,fakeObject2]
        fakeObject1.value = "oldValue"
        fakeObject2.value = "oldValue"
        try! realm.write {
            realm.add(fakeObjects)
        }
        
        let objects = self.realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        fakeObjects.update(type: FakeObject.self, realm: realm, thread: .background) { object in
            object.value = "updatedValue"
        }.on(value: {
                let objects = self.realm.objects(FakeObject.self)
                XCTAssertEqual(objects.first?.value, "updatedValue")
                XCTAssertEqual(objects.last?.value, "updatedValue")
                XCTAssertEqual(objects.count, 2)
                expectation.fulfill()
            }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testDeleteRemovesArray(){
        let fakeObjects = [FakeObject(),FakeObject()]
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        fakeObjects.delete().start()
        let emptyObjects = realm.objects(FakeObject.self)
        XCTAssertEqual(emptyObjects.count, 0)
    }
    
    func testDeleteRemovesArrayInBackground(){
        let expectation = self.expectation(description: "ready")
        let fakeObjects = [FakeObject(),FakeObject()]
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        fakeObjects.delete(realm: nil, thread: .background).on(value: {
            let objects = self.realm.objects(FakeObject.self)
            XCTAssertEqual(objects.count, 0)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    
}

class FakeObject: Object{
    dynamic var id = NSUUID().uuidString.lowercased()
    dynamic var value = ""
    
    override static func primaryKey() -> String? {
        return "id"
    }
}
