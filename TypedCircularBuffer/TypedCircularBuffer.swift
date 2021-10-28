//
//  TypedCircularBuffer.swift
//  TypedCircularBuffer
//
//  Created by Jan on 24.10.21.
//
//  MIT License
//

import Foundation


class TypedCircularBuffer<Element: Strideable> {
	private var ringBuffer: RingBuffer
	
	// MARK: Metadata
	
	private let bytesPerValue: Int = MemoryLayout<Element>.stride
	
	/// The number of elements in the buffer available for reading.
	var count: Int {
		get {
			return ringBuffer.count / bytesPerValue
		}
	}
	
	/// The total number of slots for bytes in the buffer.
	var capacity: Int {
		get {
			return Int(ringBuffer.capacity) / bytesPerValue
		}
	}
	
	/// The number of slots in the buffer available for writing.
	var available: Int {
		get {
			return Int(ringBuffer.availableBytesForWriting) / bytesPerValue
		}
	}
	
	/// A Boolean value indicating whether the collection is empty.
	var isEmpty: Bool {
		get {
			return ringBuffer.isEmpty
		}
	}
	
	/// A Boolean value indicating whether the collection is full.
	var isFull: Bool {
		get {
			return ringBuffer.isFull
		}
	}
	
	/// Write index.
	var head: Int {
		return Int(ringBuffer.headOffset) / bytesPerValue
	}
	
	/// Read index.
	var tail: Int {
		return Int(ringBuffer.tailOffset) / bytesPerValue
	}
	
	var maxCapacity: Int {
		return Int(UInt32.max) / bytesPerValue
	}
	
	
	// MARK: Lifecycle
	
	init?(minimumCapacity: Int) {
		let maxCapacity = Int(UInt32.max) / bytesPerValue
		precondition(minimumCapacity <= maxCapacity)
		let minimumSize = minimumCapacity * bytesPerValue
		
		let optionalRingBuffer = RingBuffer(minimumSize: minimumSize)
		guard let ringBuffer = optionalRingBuffer else { return nil }
		
		self.ringBuffer = ringBuffer
	}
	
	func removeAll() {
		ringBuffer.removeAll()
	}
	
	
	// MARK: Retrieve elements
	
	/**
	Pop single element
	
	- returns:
	Element or `nil` if buffer is empty
	*/
	@discardableResult public func pop() -> Element? {
		return pop(amount: 1)?.first
	}
	
	/**
	Pop multiple elements
	
	- parameters:
	- amount: Number of elements to read
	
	-  returns:
	Array of elements or `nil` if requested amount is greater than current buffer size
	*/
	@discardableResult public func pop(amount: Int) -> [Element]? {
		
		var optionalArray: [Element]?
		
		popUnsafeBuffer(amount: amount) { optionalPointer in
			if let bufferPointer = optionalPointer {
				optionalArray =  Array(bufferPointer)
			}
			else {
				optionalArray = nil
			}
		}
		
		return optionalArray
	}
	
	public func popUnsafeBuffer(amount: Int,
								_ body: (UnsafeBufferPointer<Element>?) -> ()) {
		
		let requestedSize = amount * bytesPerValue
		guard requestedSize <= ringBuffer.availableBytesForReading else {
			body(nil)
			return
		}
		
		ringBuffer.read(requestedSize: requestedSize) {
			rawPointer, availableBytes in
			let count = availableBytes / bytesPerValue

			let pointer = rawPointer.bindMemory(to: Element.self,
												capacity: count)
			let bufferPointer = UnsafeBufferPointer(start: pointer,
													count: count)
			
			body(bufferPointer)
		}
		
	}
	
	
	// MARK: Store elements
	
	/// Push single element (overwrite on overflow by default)
	public func push(_ value: Element) {
		precondition(bytesPerValue <= ringBuffer.capacity)
		var temp = value
		ringBuffer.write(&temp,
						 requestedSize: bytesPerValue)
	}
	
	/// Push multiple elements (overwrite on overflow by default)
	public func push(_ values: [Element]) {
		if values.isEmpty { return }
		
		values.withUnsafeBufferPointer { bufferPointer -> Void in
			push(bufferPointer)
		}
	}
	
	public func push(_ bufferPointer: UnsafeBufferPointer<Element>) {
		guard let pointer = bufferPointer.baseAddress else { return }
		let size = bufferPointer.count * bytesPerValue
		
		precondition(size <= ringBuffer.capacity)
		ringBuffer.write(pointer,
						 requestedSize: size)
	}
	
}
