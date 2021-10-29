//
//  RingBuffer.swift
//
//  Based on RingBuffer by Riley Testut.
//  Copyright © 2016-2020 Riley Testut. All rights reserved.
//  Copyright © 2021 Jan Weiß. All rights reserved.
//
//  Heavily based on Michael Tyson's TPCircularBuffer 
//  https://github.com/michaeltyson/TPCircularBuffer
//
//  With permission from Riley Testut released under:
//  MIT license
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  This implementation makes use of a virtual memory mapping technique that inserts a virtual copy
//  of the buffer memory directly after the buffer's end, negating the need for any buffer wrap-around
//  logic. Clients can simply use the returned memory address as if it were contiguous space.
//
//  The implementation is thread-safe in the case of a single producer and single consumer.
//
//  Virtual memory technique originally proposed by Philip Howard (http://vrb.slashusr.org/), and
//  adapted to Darwin by Kurt Revis (http://www.snoize.com,
//  http://www.snoize.com/Code/PlayBufferedSoundFile.tar.gz)

import Foundation
import Darwin.Mach.machine.vm_types

private func truncateToPreviousPageSize(_ x: vm_size_t) -> vm_size_t {
	return x & ~(vm_page_size - 1)
}

private func roundToNextPageSize(_ x: vm_size_t) -> vm_size_t {
	return truncateToPreviousPageSize(x + (vm_size_t(vm_page_size) - 1))
}

@objc(DLTARingBuffer) @objcMembers
public class RingBuffer: NSObject {
	var isEnabled: Bool = true
	
	/// The number of bytes in the buffer available for reading.
	public var count: Int {
		return Int(self.usedBytesCount)
	}
	
	/// The number of bytes in the buffer available for writing.
	public var availableBytesForWriting: Int {
		return self.capacity - self.count
	}
	
	/// The number of bytes in the buffer available for reading.
	public var availableBytesForReading: Int {
		return self.count
	}
	
	/// A Boolean value indicating whether the collection is empty.
	public var isEmpty: Bool {
		return self.availableBytesForReading == 0
	}
	
	/// A Boolean value indicating whether the collection is full.
	public var isFull: Bool {
		return self.availableBytesForWriting == self.count
	}
	
	/// Write pointer.
	private var head: UnsafeMutableRawPointer {
		let head = self.buffer.advanced(by: self.headOffset)
		return head
	}
	
	/// Read pointer.
	private var tail: UnsafeMutableRawPointer {
		let head = self.buffer.advanced(by: self.tailOffset)
		return head
	}
	
	/// The total number of slots for bytes in the buffer.
	public private(set) var capacity = 0
	
	/// Pointer to the internal, mirrored buffer.
	private let buffer: UnsafeMutableRawPointer
	
	/// Read index.
	public private(set) var tailOffset = 0
	
	/// Write index.
	public private(set) var headOffset = 0
	
	/// The internal number of bytes in the buffer available for reading.
	private var usedBytesCount: Int32 = 0
	
	/// Equivalent to `_TPCircularBufferInit()`
	init?(minimumSize: Int) {
		assert(minimumSize > 0)
		
		// To handle race conditions, repeat initialization process
		// up to 3 times before failing.
		for _ in 1...3 {
			let length = roundToNextPageSize(vm_size_t(minimumSize))
			
			// Temporarily allocate twice the `length`,
			// so we have the contiguous address space to
			// support a second instance of the buffer directly after.
			var bufferAddress: vm_address_t = 0
			guard vm_allocate(mach_task_self_,
							  &bufferAddress,
							  vm_size_t(length * 2),
							  // Allocate anywhere it will fit.
							  VM_FLAGS_ANYWHERE) == ERR_SUCCESS
			else { continue }
			
			// Now replace the second half of the allocation
			// with a virtual copy of the first half.
			// Deallocate the second half…
			guard vm_deallocate(mach_task_self_, bufferAddress + length, length) == ERR_SUCCESS else {
				// If this fails somehow, deallocate the whole region and try again.
				vm_deallocate(mach_task_self_, bufferAddress, length)
				
				continue
			}
			
			// Re-map the buffer to the address space immediately after the buffer.
			var virtualAddress: vm_address_t = bufferAddress + length
			var currentProtection: vm_prot_t = 0
			var maxProtection: vm_prot_t = 0
			
			guard vm_remap(mach_task_self_,
						   &virtualAddress,		// Mirror target.
						   length,				// Size of mirror.
						   0,					// Auto-alignment.
						   0,					// Force remapping to `virtualAddress`.
						   mach_task_self_,		// Target the same task.
						   bufferAddress,		// Mirror source.
						   0,					// Map as read-write, NOT copy.
						   &currentProtection,	// Unused protection struct.
						   &maxProtection,		// Unused protection struct.
						   VM_INHERIT_DEFAULT) == ERR_SUCCESS else {
				// If this remap failed, we hit a race condition,
				// so deallocate and try again.
				vm_deallocate(mach_task_self_, bufferAddress, length)
				
				continue
			}
			
			guard virtualAddress == bufferAddress + length else {
				// If the memory is not contiguous,
				// clean up both allocated buffers and try again.
				vm_deallocate(mach_task_self_, virtualAddress, length)
				vm_deallocate(mach_task_self_, bufferAddress, length)
				
				continue
			}
			
			self.buffer = UnsafeMutableRawPointer(bitPattern: UInt(bufferAddress))!
			self.capacity = Int(length)
			
			return
		}
		
		return nil
	}
	
	/// Equivalent to `TPCircularBufferCleanup()`.
	deinit {
		let address = UInt(bitPattern: self.buffer)
		vm_deallocate(mach_task_self_, vm_address_t(address), vm_size_t(self.capacity * 2))
	}
}

public extension RingBuffer {
	/// Writes `size` bytes from `buffer` to ring buffer if possible. Otherwise, writes as many as possible.
	/// Returns the number of bytes written.
	/// Equivalent to `TPCircularBufferTail()` + `TPCircularBufferConsume()`.
	@objc(writeBuffer:size:)
	@discardableResult func write(_ buffer: UnsafeRawPointer,
								  requestedSize: Int) -> Int {
		guard self.isEnabled else { return 0 }
		guard self.availableBytesForWriting > 0 else { return 0 }
		
		if requestedSize > self.availableBytesForWriting {
			print("Ring Buffer Capacity reached. Available: \(self.availableBytesForWriting). Requested: \(requestedSize) Max: \(self.capacity). Filled: \(self.usedBytesCount).")
			
			self.removeAll()
		}
		
		let size = min(requestedSize, self.availableBytesForWriting)
		memcpy(self.head, buffer, size)
		
		/// Mark written bytes as ready for reading.
		self.decrementAvailableBytes(by: size)
		
		return size
	}
	
	
	func read(requestedSize: Int,
			  _ body: (_ rawReadPointer: UnsafeMutableRawPointer,
					   _ size: Int) -> ()) {
		guard self.isEnabled else { return }
		guard self.availableBytesForReading > 0 else { return }
		
		if requestedSize > self.availableBytesForReading {
			print("Ring Buffer Empty. Available: \(self.availableBytesForReading). Requested: \(requestedSize) Max: \(self.capacity). Filled: \(self.usedBytesCount).")
			
			self.removeAll()
		}
		
		let size = min(requestedSize, self.availableBytesForReading)
		body(self.tail, size)
		
		/// Mark bytes as available space, ready for writing to once more.
		self.incrementAvailableBytes(by: size)
	}
	
	/// Copies `size` bytes from ring buffer to `buffer` if possible. Otherwise, copies as many as possible.
	/// Returns the number of bytes read.
	/// Equivalent to `TPCircularBufferProduceBytes()`.
	@objc(readIntoBuffer:requestedSize:)
	@discardableResult func read(into buffer: UnsafeMutableRawPointer,
								 requestedSize: Int) -> Int {
		var readSize: Int = 0
		
		read(requestedSize: requestedSize) { rawReadPointer, size in
			memcpy(buffer, rawReadPointer, size)
			readSize = size
		}
		
		return readSize
	}
	
	func readBuffer(requestedSize: Int,
					_ body: (UnsafeBufferPointer<Int8>) -> ()) {
		
		read(requestedSize: requestedSize) {
			rawReadPointer, size in
			let readPointer = rawReadPointer.bindMemory(to: Int8.self,
														capacity: size)
			let bufferPointer = UnsafeBufferPointer(start: readPointer,
													count: size)
			
			body(bufferPointer)
		}
		
	}
	
	/// Equivalent to `TPCircularBufferClear()`.
	func removeAll() {
		let size = self.availableBytesForReading
		self.incrementAvailableBytes(by: size)
	}
}

private extension RingBuffer {
	func incrementAvailableBytes(by size: Int) {
		self.tailOffset = (self.tailOffset + size) % self.capacity
		OSAtomicAdd32(-Int32(size), &self.usedBytesCount)
	}
	
	func decrementAvailableBytes(by size: Int) {
		self.headOffset = (self.headOffset + size) % self.capacity
		OSAtomicAdd32(Int32(size), &self.usedBytesCount)
	}
}
