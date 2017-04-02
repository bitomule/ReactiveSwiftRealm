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
import ReactiveSwiftRealm

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
        
        fakeObject.update() { object in
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
            fakeObject.update() { object in
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
        fakeObject.update(thread: .background) { object in
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
        fakeObject.update(thread: .background) { object in
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
        
        fakeObjects.update() { object in
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
        
        fakeObjects.update( thread: .background) { object in
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
    
    func testFindByKeySendsObject(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.id = "objectId"
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        FakeObject.findBy(key: "objectId").on(value: { object in
            XCTAssertNotNil(object, "")
            XCTAssertEqual(object!.id, "objectId")
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByKeySendsNilWhenObjectNoExists(){
        let expectation = self.expectation(description: "ready")
        
        FakeObject.findBy(key: "objectId").on(value: { object in
            XCTAssertNil(object)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByKeySendsErrorWhenNotOnMainThread(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.id = "objectId"
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        DispatchQueue(label: "background").async {
            FakeObject.findBy(key: "objectId").on(failed: { error in
                XCTAssertEqual(error, ReactiveSwiftRealmError.wrongThread)
                expectation.fulfill()
            }).start()
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByQuerySendsObjects(){
        let expectation = self.expectation(description: "ready")
        let fakeObjects = [FakeObject(),FakeObject()]
        for fakeObject in fakeObjects{
            fakeObject.value = "testValue"
        }
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        FakeObject.findBy(query: "value == \"testValue\"").on(value: { results in
            XCTAssertEqual(results.count, 2)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByQuerySendsOnlyMatchingObjects(){
        let expectation = self.expectation(description: "ready")
        let matchingObject = FakeObject()
        let fakeObjects = [matchingObject,FakeObject()]
        matchingObject.value = "testValue"
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        FakeObject.findBy(query: "value == \"testValue\"").on(value: { results in
            XCTAssertEqual(results.count, 1)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByQuerySendsErrorWhenNotOnMainThread(){
        let expectation = self.expectation(description: "ready")
        let fakeObjects = [FakeObject(),FakeObject()]
        for fakeObject in fakeObjects{
            fakeObject.value = "testValue"
        }
        try! realm.write {
            realm.add(fakeObjects)
        }
        
        DispatchQueue(label: "background").async {
            FakeObject.findBy(query: "value == \"testValue\"").on(failed: { error in
                XCTAssertEqual(error, ReactiveSwiftRealmError.wrongThread)
                expectation.fulfill()
            }).start()
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testReactiveFindByQuerySendsValueWhenChanged(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.id = "objectId"
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        FakeObject.findBy(query: "id == \"objectId\"").reactive().skip(first: 1).on(value: { results in
            XCTAssertEqual(results.value.count, 1)
            XCTAssertEqual(results.value.first!.value, "newValue")
            expectation.fulfill()
        }).start()
        
        try! realm.write {
            fakeObject.value = "newValue"
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testReactiveFindByQuerySendsInitialValue(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.id = "objectId"
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        var firstValueSended = false
        
        FakeObject.findBy(query: "id == \"objectId\"").reactive().on(value: { results in
            guard !firstValueSended else {return}
            firstValueSended = true
            XCTAssertEqual(results.value.count, 1)
            XCTAssertEqual(results.value.first!.value, "oldValue")
            expectation.fulfill()
        }).start()
        
        try! realm.write {
            fakeObject.value = "newValue"
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testReactiveFindByQuerySendsAdded(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        fakeObject1.value = "fakeObjectValue"
        try! realm.write {
            realm.add(fakeObject1)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        FakeObject.findBy(query: "value == \"fakeObjectValue\"").reactive().skip(first: 1).on(value: { results in
            XCTAssertEqual(results.value.count, 2)
            XCTAssertEqual(results.changes!.inserted.count, 1)
            expectation.fulfill()
        }).start()
        
        let fakeObject2 = FakeObject()
        fakeObject2.value = "fakeObjectValue"
        try! realm.write {
            realm.add(fakeObject2)
        }

        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testReactiveFindByQuerySendsUpdated(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.id = "objectId"
        fakeObject.value = "oldValue"
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        FakeObject.findBy(query: "id == \"objectId\"").reactive().skip(first: 1).on(value: { results in
            XCTAssertEqual(results.value.count, 1)
            XCTAssertEqual(results.changes!.updated.count, 1)
            expectation.fulfill()
        }).start()
        
        try! realm.write {
            fakeObject.value = "newValue"
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testReactiveFindByQuerySendsDeleted(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.id = "objectId"
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        FakeObject.findBy(query: "id == \"objectId\"").reactive().skip(first: 1).on(value: { results in
            XCTAssertEqual(results.value.count, 0)
            XCTAssertEqual(results.changes!.deleted.count, 1)
            expectation.fulfill()
        }).start()
        
        try! realm.write {
            realm.delete(fakeObject)
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testReactiveFindByQuerySendsInitialChanges(){
        let expectation = self.expectation(description: "ready")
        let fakeObject = FakeObject()
        fakeObject.id = "objectId"
        try! realm.write {
            realm.add(fakeObject)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 1)
        
        FakeObject.findBy(query: "id == \"objectId\"").reactive().on(value: { results in
            XCTAssertEqual(results.value.count, 1)
            XCTAssertEqual(results.changes!.inserted.count, 1)
            expectation.fulfill()
        }).start()
        
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByQuerySortedAscending(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        fakeObject1.sortIndex = 1
        let fakeObject2 = FakeObject()
        fakeObject2.sortIndex = 2
        let fakeObjects = [fakeObject1,fakeObject2]
        for fakeObject in fakeObjects{
            fakeObject.value = "testValue"
        }
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        FakeObject.findBy(query: "value == \"testValue\"").sorted(key: "sortIndex",ascending:true).on(value: { results in
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results.first!.sortIndex, 1)
            XCTAssertEqual(results.last!.sortIndex, 2)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByQuerySortedDescending(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        fakeObject1.sortIndex = 1
        let fakeObject2 = FakeObject()
        fakeObject2.sortIndex = 2
        let fakeObjects = [fakeObject1,fakeObject2]
        for fakeObject in fakeObjects{
            fakeObject.value = "testValue"
        }
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        FakeObject.findBy(query: "value == \"testValue\"").sorted(key: "sortIndex",ascending:false).on(value: { results in
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(results.first!.sortIndex, 2)
            XCTAssertEqual(results.last!.sortIndex, 1)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByQuerySortedReactiveSendsSortedValues(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        fakeObject1.sortIndex = 1
        let fakeObject2 = FakeObject()
        fakeObject2.sortIndex = 2
        let fakeObjects = [fakeObject1,fakeObject2]
        for fakeObject in fakeObjects{
            fakeObject.value = "testValue"
        }
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        FakeObject.findBy(query: "value == \"testValue\"").sorted(key: "sortIndex",ascending:false).reactive().on(value: { results in
            XCTAssertEqual(results.value.count, 2)
            XCTAssertEqual(results.value.first!.sortIndex, 2)
            XCTAssertEqual(results.value.last!.sortIndex, 1)
            expectation.fulfill()
        }).start()
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
    
    func testFindByQuerySortedReactiveSendsSortedValuesWhenAdded(){
        let expectation = self.expectation(description: "ready")
        let fakeObject1 = FakeObject()
        fakeObject1.sortIndex = 1
        let fakeObject2 = FakeObject()
        fakeObject2.sortIndex = 2
        let fakeObjects = [fakeObject1,fakeObject2]
        for fakeObject in fakeObjects{
            fakeObject.value = "testValue"
        }
        try! realm.write {
            realm.add(fakeObjects)
        }
        let objects = realm.objects(FakeObject.self)
        XCTAssertEqual(objects.count, 2)
        
        FakeObject.findBy(query: "value == \"testValue\"").sorted(key: "sortIndex",ascending:false).reactive().skip(first: 1).on(value: { results in
            XCTAssertEqual(results.value.count, 3)
            XCTAssertEqual(results.value.first!.sortIndex, 5)
            expectation.fulfill()
        }).start()
        
        let fakeObject3 = FakeObject()
        fakeObject3.value = "testValue"
        fakeObject3.sortIndex = 5
        
        try! realm.write {
            realm.add(fakeObject3)
        }
        
        waitForExpectations(timeout: 0.1){ error in
            
        }
    }
  
  func testFindAllSendsAllObjects(){
    let expectation = self.expectation(description: "ready")
    let fakeObjects = [FakeObject(),FakeObject()]
    for fakeObject in fakeObjects{
      fakeObject.value = "testValue"
    }
    try! realm.write {
      realm.add(fakeObjects)
    }
    let objects = realm.objects(FakeObject.self)
    XCTAssertEqual(objects.count, 2)
    
    FakeObject.findAll().on(value: { results in
      XCTAssertEqual(results.count, 2)
      expectation.fulfill()
    }).start()
    
    waitForExpectations(timeout: 0.1){ error in
      
    }
  }
  
}

class FakeObject: Object{
    dynamic var id = NSUUID().uuidString.lowercased()
    dynamic var value = ""
    dynamic var sortIndex = 0
    
    override static func primaryKey() -> String? {
        return "id"
    }
}

