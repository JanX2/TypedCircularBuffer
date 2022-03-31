//
//  TypedCircularBuffer.swift
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

import Foundation


class TypedCircularBuffer<Element: Strideable> {
	private var circularBuffer: CircularBuffer
	
	// MARK: Metadata
	
	private let bytesPerValue: Int = MemoryLayout<Element>.stride
	
	/// The number of elements in the buffer available for reading.
	var count: Int {
		get {
			return circularBuffer.count / bytesPerValue
		}
	}
	
	/// The total number of slots for bytes in the buffer.
	var capacity: Int {
		get {
			return Int(circularBuffer.capacity) / bytesPerValue
		}
	}
	
	/// The capacity multiple of the buffer.
	static var capacityGranularity: Int {
		return CircularBuffer.capacityGranularity / MemoryLayout<Element>.stride
	}
	
	/// The number of slots in the buffer available for writing.
	var available: Int {
		get {
			return Int(circularBuffer.availableBytesForWriting) / bytesPerValue
		}
	}
	
	/// A Boolean value indicating whether the collection is empty.
	var isEmpty: Bool {
		get {
			return circularBuffer.isEmpty
		}
	}
	
	/// A Boolean value indicating whether the collection is full.
	var isFull: Bool {
		get {
			return circularBuffer.isFull
		}
	}
	
	/// Write index.
	var head: Int {
		return Int(circularBuffer.headOffset) / bytesPerValue
	}
	
	/// Read index.
	var tail: Int {
		return Int(circularBuffer.tailOffset) / bytesPerValue
	}
	
	var maxCapacity: Int {
		return Int(UInt32.max) / bytesPerValue
	}
	
	
	// MARK: Lifecycle
	
	init?(minimumCapacity: Int) {
		let minimumSize = minimumCapacity * bytesPerValue
		
		let optionalCircularBuffer = CircularBuffer(minimumSize: minimumSize)
		guard let circularBuffer = optionalCircularBuffer else { return nil }
		
		self.circularBuffer = circularBuffer
		
		assert(minimumSize <= circularBuffer.capacity)
	}
	
	deinit {
		circularBuffer.cleanup()
	}
	
	func removeAll() {
		circularBuffer.removeAll()
	}
	
	
	// MARK: Retrieve elements
	
	/**
	Pop single element
	Removes the read element

	- returns:
	Element or `nil` if buffer is empty
	*/
	@discardableResult public func pop() -> Element? {
		return pop(amount: 1)?.first
	}
	
	/**
	Pop multiple elements
	Removes the read elements
	
	- parameters:
	- amount: Number of elements to read
	
	-  returns:
	Array of elements or `nil` if requested amount is greater than current buffer size
	*/
	@discardableResult public func pop(amount: Int) -> [Element]? {
		return read(amount: amount,
					markAsAvailable: true)
	}
	
	/**
	Peek at multiple elements
	Doesn’t remove what was read

	- parameters:
	- amount: Number of elements to read
	
	-  returns:
	Array of elements or `nil` if requested amount is greater than current buffer size
	*/
	@discardableResult public func peekAt(amount: Int) -> [Element]? {
		return read(amount: amount,
					markAsAvailable: false)
	}
	
	private func read(amount: Int,
					  markAsAvailable: Bool) -> [Element]? {
		
		var optionalArray: [Element]?
		
		readUnsafeBuffer(amount: amount,
						 markAsAvailable: markAsAvailable) { optionalPointer in
			if let bufferPointer = optionalPointer {
				optionalArray =  Array(bufferPointer)
			}
			else {
				optionalArray = nil
			}
		}
		
		return optionalArray
	}
	
	/**
	Pop multiple elements
	Removes the the read elements
	
	- parameters:
	- amount: Number of elements to read
	- body: Closure that is called with a temporary buffer of elements ready for reading or nil if not enough elements are available

	-  returns:
	Array of elements or `nil` if requested amount is greater than current buffer size
	*/
	public func popUnsafeBuffer(amount: Int,
								_ body: (UnsafeBufferPointer<Element>?) -> ()) {
		readUnsafeBuffer(amount: amount,
						 markAsAvailable: true,
						 body)
	}
	
	/**
	Peek at multiple elements
	Doesn’t remove the read elements

	- parameters:
	- amount: Number of elements to read
	- body: Closure that is called with a temporary buffer of elements ready for reading or nil if not enough elements are available
	
	-  returns:
	Array of elements or `nil` if requested amount is greater than current buffer size
	*/
	public func peekAtUnsafeBuffer(amount: Int,
								   _ body: (UnsafeBufferPointer<Element>?) -> ()) {
		readUnsafeBuffer(amount: amount,
						 markAsAvailable: false,
						 body)
	}
	
	/**
	Removes elements
	For example those that have been previously peeked at or are not needed anymore
	
	- parameters:
	- amount: Number of elements to remove
	
	-  returns:
	Number of elements removed
	*/
	public func flush(amount: Int) -> Int {
		let size = amount * bytesPerValue
		let flushedSize =
			circularBuffer.markAsAvailable(requestedSize: size)
		
		let flushedAmount = flushedSize / bytesPerValue
		return flushedAmount
	}
	
	
	public func readUnsafeBuffer(amount: Int,
								 markAsAvailable: Bool,
								 _ body: (UnsafeBufferPointer<Element>?) -> ()) {
		let requestedSize = amount * bytesPerValue
		guard requestedSize <= circularBuffer.availableBytesForReading else {
			body(nil)
			return
		}
		
		circularBuffer.read(requestedSize: requestedSize,
							markAsAvailable: markAsAvailable) {
			rawBytes, availableBytes in
			
			precondition(Int(bitPattern: rawBytes)
							.isMultiple(of: MemoryLayout<Element>.alignment))
			
			let count = availableBytes / bytesPerValue
			
			let pointer = rawBytes.bindMemory(to: Element.self,
											  capacity: count)
			let bufferPointer = UnsafeBufferPointer(start: pointer,
													count: count)
			
			body(bufferPointer)
		}
		
	}
	
	
	// MARK: Store elements
	
	/// Push single element
	@discardableResult public func push(_ value: Element) -> Bool {
		precondition(bytesPerValue <= circularBuffer.capacity)
		var temp = value
		
		let writtenSize =
			circularBuffer.write(&temp,
								 requestedSize: bytesPerValue)
		
		return writtenSize == bytesPerValue
	}
	
	/// Push multiple elements
	@discardableResult public func push(_ values: [Element]) -> Int {
		if values.isEmpty { return 0 }
		
		var writtenAmount = 0
		
		values.withUnsafeBufferPointer { bufferPointer -> Void in
			writtenAmount = push(bufferPointer)
		}
		
		return writtenAmount
	}
	
	/// Push multiple elements sourced from a buffer
	@discardableResult public func push(_ bufferPointer: UnsafeBufferPointer<Element>) -> Int {
		guard let pointer = bufferPointer.baseAddress else { return 0 }
		let size = bufferPointer.count * bytesPerValue
		
		precondition(size <= circularBuffer.capacity)
		let writtenSize =
			circularBuffer.write(pointer,
								 requestedSize: size)
		
		let writtenAmount = writtenSize / bytesPerValue
		return writtenAmount
	}
	
}
