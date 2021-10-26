//
//  TPCircularBuffer.swift
//  TypedCircularBuffer
//
//  Created by Jan on 24.10.21.
//

import Foundation


extension TPCircularBuffer {
	
	// MARK: Lifecycle
	
	init(size: UInt32) {
		self.init()
		_TPCircularBufferInit(&self, size, MemoryLayout<TPCircularBuffer>.size)
	}
	
	/// Required. It’s a good idea to call this via `defer` or from a `deinit`.
	mutating func cleanup() {
		TPCircularBufferCleanup(&self)
	}
	
	
	mutating func clearAll() {
		TPCircularBufferClear(&self)
	}
	
	
	// MARK: Retrieve data
	
	mutating func yieldAvailableBytes() -> (readPointer: UnsafeMutableRawPointer?,
											availableBytes: UInt32) {
		var availableBytes: UInt32 = 0
		let tail = TPCircularBufferTail(&self, &availableBytes)
		return (readPointer: tail,
				availableBytes: availableBytes)
	}
	
	/// Mark bytes as available space, ready for writing to once more.
	mutating func freeUpBytes(size: UInt32) {
		TPCircularBufferConsume(&self, size)
	}
	
	
	// MARK: Store data
	
	mutating func prepareWrite() -> (writePointer: UnsafeMutableRawPointer?,
									 availableBytes: UInt32) {
		var availableBytes: UInt32 = 0
		let writePointer = TPCircularBufferHead(&self, &availableBytes)
		return (writePointer: writePointer,
				availableBytes: availableBytes)
	}
	
	/// Mark written bytes as ready for reading.
	mutating func markWrittenBytesReadyForReading(size: UInt32) {
		return TPCircularBufferProduce(&self, size)
	}
	
	/// Combines the previous two functions in a single, convenient call.
	@discardableResult mutating func storeBytes(from sourcePointer: UnsafeRawPointer,
												size: UInt32) -> Bool {
		return TPCircularBufferProduceBytes(&self, sourcePointer, size)
	}
	
	
	// MARK: Optimization
	
	var atomicOperations: Bool {
		get {
			return self.atomic
		}
		set {
			TPCircularBufferSetAtomic(&self, newValue)
		}
	}
	
	
	// MARK: Metadata
	
	/// The number of bytes in the buffer available for reading.
	var count: UInt32 {
		mutating get {
			return self.availableBytes
		}
	}

	/// The total number of slots for bytes in the buffer.
	var capacity: UInt32 {
		get {
			return self.length
		}
	}
	
	/// The number of bytes in the buffer available for reading.
	var availableBytes: UInt32 {
		mutating get {
			var availableBytes: UInt32 = 0
			_ = TPCircularBufferTail(&self, &availableBytes)
			
			return availableBytes
		}
	}
	
	/// A Boolean value indicating whether the collection is empty.
	var isEmpty: Bool {
		mutating get {
			return self.availableBytes == 0
		}
	}
	
	/// A Boolean value indicating whether the collection is full.
	var isFull: Bool {
		mutating get {
			return self.availableBytes == self.length
		}
	}
}
