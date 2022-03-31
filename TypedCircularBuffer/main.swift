//
//  main.swift
//  TypedCircularBuffer
//
//  Created by Jan on 24.10.21.
//

import Foundation
import Accelerate


typealias Sample  = Float

typealias Buffer = TypedCircularBuffer<Sample>


let count = 1024

let buffer = Buffer(minimumCapacity: count)!


// Fill `samples` array with a ramp. We could also create and use an UnsafeBufferPointer directly.
let samples = Array<Sample>(unsafeUninitializedCapacity: count) { bufferPointer, initializedCount in
	let samplesPointer = bufferPointer.baseAddress!
	let samplesCount = vDSP_Length(bufferPointer.count)
	
	var start = Sample(0.0)
	var end = Sample(count-1)
	vDSP_vgen(&start, &end, samplesPointer, 1, samplesCount)
	
	initializedCount = bufferPointer.count
}

// Add samples to `buffer`.
let addedSamples = samples.withUnsafeBufferPointer { bufferPointer in
	buffer.push(bufferPointer)
}

assert(addedSamples == count)

// Use `buffer` contents:
#if false
// Method #1: consume samples directly.
buffer.popUnsafeBuffer(amount: buffer.count) { optionalBufferPointer in
	guard let bufferPointer = optionalBufferPointer else { return }
	
	for sample in bufferPointer {
		print(sample)
	}
}
#else
// Method #2: peek at samples and flush them once we don‘t need them anymore.
buffer.peekAtUnsafeBuffer(amount: count) { optionalBufferPointer in
	guard let bufferPointer = optionalBufferPointer else { return }
	
	for sample in bufferPointer {
		print(sample)
	}
}

let samplesLeft = buffer.count

let flushed = buffer.flush(amount: samplesLeft)
#endif
