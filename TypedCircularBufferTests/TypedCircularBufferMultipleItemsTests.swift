//
//  TypedCircularBufferMultipleItemsTests.swift
//  TypedCircularBuffer
//
//  Created by Jan on 26.10.21.
//
//  Partially based on RingBufferMultipleItemsTests from
//  https://github.com/Galarius/ring-buffer

import XCTest


typealias Buffer = TypedCircularBuffer


final class TypedCircularBufferMultipleItemsTests: XCTestCase {
	
	func testPushMultipleItems() {
		let items = [1, 2, 3, 4, 5]
		let buffer = Buffer<Int>(minimumCapacity: items.count)!
		buffer.push(items)
		XCTAssertEqual(buffer.count, items.count, "Buffer is not full")
	}
	
	func testPopMultipleItems() {
		let items = [1, 2, 3, 4, 5, 6]
		let buffer = Buffer<Int>(minimumCapacity: 6)!
		buffer.push(items)
		XCTAssertEqual(buffer.pop(amount: 4), [1, 2, 3, 4])
		XCTAssertEqual(buffer.pop(amount: 2), [5, 6])
		XCTAssert(buffer.isEmpty)
	}
	
	func testPopMultipleItemsWithOverflow() {
		let items = [1, 2, 3, 4, 5, 6]
		let buffer = Buffer<Int>(minimumCapacity: items.count)!
		buffer.push(items)
		XCTAssertEqual(buffer.pop(amount: items.count + 1), nil)
		XCTAssertEqual(buffer.pop(amount: items.count), items)
		XCTAssert(buffer.isEmpty)
	}
	
	static var allTests = [
		("testPushMultipleItems", testPushMultipleItems),
		("testPopMultipleItems", testPopMultipleItems),
		("testPopMultipleItemsWithOverflow", testPopMultipleItemsWithOverflow),
	]
}

