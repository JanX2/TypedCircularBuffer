//
//  TypedCircularBufferMultipleItemsTests.swift
//  TypedCircularBuffer
//
//  Copyright © 2021-2022 Jan Weiß. All rights reserved.
//
//  MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
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

