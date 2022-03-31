//
//  main.swift
//  TypedCircularBuffer
//
//  MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
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
