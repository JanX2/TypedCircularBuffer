//
//  TypedCircularBufferMultipleItemsTests.swift
//  TypedCircularBuffer
//
//  Created by Jan on 26.10.21.
//
//  Partially based on RingBufferMultipleItemsTests from
//  https://github.com/Galarius/ring-buffer

import XCTest


typealias Buffer = TypedCircularBuffer<Int>


final class TypedCircularBufferMultipleItemsTests: XCTestCase {
	
	func testPushMultipleItems() {
		let items = [1, 2, 3, 4, 5]
		let buffer = Buffer(minimumCapacity: items.count)!
		buffer.push(items)
		XCTAssertEqual(buffer.count, items.count, "Buffer is not full")
	}
	
	func testPopMultipleItems() {
		let items = [1, 2, 3, 4, 5, 6]
		let buffer = Buffer(minimumCapacity: 6)!
		buffer.push(items)
		XCTAssertEqual(buffer.pop(amount: 4), [1, 2, 3, 4])
		XCTAssertEqual(buffer.pop(amount: 2), [5, 6])
		XCTAssert(buffer.isEmpty)
	}
	
	func testPopMultipleItemsWithOverflow() {
		let items = [1, 2, 3, 4, 5, 6]
		let buffer = Buffer(minimumCapacity: items.count)!
		buffer.push(items)
		XCTAssertEqual(buffer.pop(amount: items.count + 1), nil)
		XCTAssertEqual(buffer.pop(amount: items.count), items)
		XCTAssert(buffer.isEmpty)
	}
	
	func testPeekAtMultipleItems() {
		let items = [1, 2, 3, 4, 5, 6]
		let buffer = Buffer(minimumCapacity: 6)!
		buffer.push(items)
		
		XCTAssertEqual(buffer.peekAt(amount: 4), [1, 2, 3, 4])
		XCTAssertEqual(buffer.flush(amount: 4), 4)

		XCTAssertEqual(buffer.peekAt(amount: 2), [5, 6])
		XCTAssertEqual(buffer.flush(amount: 2), 2)
		
		XCTAssert(buffer.isEmpty)
	}
	
	func testLargeAmountsOfItems() {
		let count = 2 * Buffer.capacityGranularity - 100
		let items = Array(0..<count)
		
		let buffer = Buffer(minimumCapacity: items.count)!
		let capacity = buffer.capacity
		XCTAssert(capacity >= count)
		
		buffer.push(items)
		XCTAssertEqual(buffer.pop(amount: items.count), items)
		XCTAssert(buffer.isEmpty)

		// Fill over capacity.
		XCTAssertEqual(buffer.push(items), items.count)
		XCTAssert(buffer.count + items.count > capacity)
		XCTAssertEqual(buffer.push(items), 0) // Test filling over capacity. Fails by not writing the items. Clears buffer.
		XCTAssertEqual(buffer.count, 0)
		
		// Fill completely.
		XCTAssertEqual(buffer.push(items), items.count)
		let capacityRemaining = buffer.available
		let partOfItems = Array(items[0..<capacityRemaining])
		XCTAssertEqual(buffer.push(partOfItems), capacityRemaining)
		XCTAssertEqual(buffer.pop(amount: items.count), items)
		XCTAssertEqual(buffer.pop(amount: buffer.count), partOfItems)
		
		XCTAssert(buffer.isEmpty)
	}
	
	static var allTests = [
		("testPushMultipleItems", testPushMultipleItems),
		("testPopMultipleItems", testPopMultipleItems),
		("testPopMultipleItemsWithOverflow", testPopMultipleItemsWithOverflow),
		("testPeekAtMultipleItems", testPeekAtMultipleItems),
		("testLargeAmountsOfItems", testLargeAmountsOfItems),
	]
}

