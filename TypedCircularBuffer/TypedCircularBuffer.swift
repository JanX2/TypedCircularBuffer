//
//  TypedCircularBuffer.swift
//  TypedCircularBuffer
//
//  Created by Jan on 24.10.21.
//
//  MIT License
//

import Foundation


public struct TypedCircularBuffer<Element: Strideable> {
	private var circularBuffer: TPCircularBuffer
	
	
	// MARK: Metadata
	
	private let bytesPerValue: Int = MemoryLayout<Element>.stride
	
	var count: Int {
		mutating get {
			return Int(circularBuffer.count) / bytesPerValue
		}
	}
	
	/// The total number of slots for bytes in the buffer.
	var capacity: Int {
		get {
			return Int(circularBuffer.capacity) / bytesPerValue
		}
	}
	
	/// The number of slots in the buffer available for writing.
	var available: Int {
		mutating get {
			return Int(circularBuffer.availableBytes) / bytesPerValue
		}
	}
	
	/// A Boolean value indicating whether the collection is empty.
	var isEmpty: Bool {
		mutating get {
			return circularBuffer.isEmpty
		}
	}
	
	/// A Boolean value indicating whether the collection is full.
	var isFull: Bool {
		mutating get {
			return circularBuffer.isFull
		}
	}
	
	/// Write index.
	var head: Int {
		return Int(circularBuffer.head) / bytesPerValue
	}
	
	/// Read index.
	var tail: Int {
		return Int(circularBuffer.tail) / bytesPerValue
	}
	
	var maxCapacity: Int {
		return Int(UInt32.max) / bytesPerValue
	}
	
	
	// MARK: Lifecycle
	
	init(minimumCapacity: Int) {
		let maxCapacity = Int(UInt32.max) / bytesPerValue
		precondition(minimumCapacity <= maxCapacity)
		
		circularBuffer = TPCircularBuffer(size: UInt32(minimumCapacity * bytesPerValue))
	}
	
	/// Required. It’s a good idea to call this via `defer` or from a `deinit`.
	mutating func cleanup() {
		circularBuffer.cleanup()
	}
	
	mutating func removeAll() {
		circularBuffer.clearAll()
	}
	
	
	// MARK: Retrieve elements
	
	/**
	Pop single element
	
	- returns:
	Element or `nil` if buffer is empty
	*/
	@discardableResult public mutating func pop() -> Element? {
		return pop(amount: 1)?.first
	}
	
	/**
	Pop multiple elements
	
	- parameters:
	- amount: Number of elements to read
	
	-  returns:
	Array of elements or `nil` if requested amount is greater than current buffer size
	*/
	@discardableResult public mutating func pop(amount: Int) -> [Element]? {
		let optionalPointer = popBuffer(amount: amount)
		
		guard let bufferPointer = optionalPointer else { return nil }
		
		let array = Array(bufferPointer)
		
		return array
	}
	
	@discardableResult public mutating func popBuffer(amount: Int) -> UnsafeBufferPointer<Element>? {
		let (optionalPointer, availableBytes) = circularBuffer.yieldAvailableBytes()
		
		guard let rawPointer = optionalPointer else { return nil }
		let count = Int(availableBytes) / bytesPerValue
		
		guard amount <= count else { return nil }
		
		let pointer = rawPointer.bindMemory(to: Element.self,
											capacity: count)
		let bufferPointer = UnsafeBufferPointer(start: pointer,
												count: amount)
		
		let readSize = UInt32(amount * bytesPerValue)
		circularBuffer.freeUpBytes(size: readSize)
		
		return bufferPointer
	}
	
	
	// MARK: Store elements
	
	/// Push single element (overwrite on overflow by default)
	public mutating func push(_ value: Element) {
		precondition(bytesPerValue <= circularBuffer.capacity)
		var temp = value
		circularBuffer.storeBytes(from: &temp,
								  size: UInt32(bytesPerValue))
	}
	
	/// Push multiple elements (overwrite on overflow by default)
	public mutating func push(_ values: [Element]) {
		if values.isEmpty { return }
		
		values.withUnsafeBufferPointer { bufferPointer -> Void in
			push(bufferPointer)
		}
	}
	
	public mutating func push(_ bufferPointer: UnsafeBufferPointer<Element>) {
		guard let pointer = bufferPointer.baseAddress else { return }
		let size = bufferPointer.count * bytesPerValue
		
		precondition(size <= circularBuffer.capacity)
		circularBuffer.storeBytes(from: pointer,
								  size: UInt32(size))
	}
	
}
