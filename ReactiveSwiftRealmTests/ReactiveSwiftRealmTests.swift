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
    
}

class FakeObject: Object{
    dynamic var id = ""
    dynamic var value = ""
}
