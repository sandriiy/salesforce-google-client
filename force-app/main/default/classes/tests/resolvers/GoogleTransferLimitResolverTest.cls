/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
@IsTest
private class GoogleTransferLimitResolverTest {
	private static final Integer HEAP_LIMIT_BEFORE_WINTER_27 = 6000000;
	private static final Integer HEAP_LIMIT_WINTER_27 = 10000000;
	private static final Long DRIVE_CHUNK_ALIGNMENT = 262144L;

	private static Long asynchronousCalloutBodyLimit;

	private class CalloutLimitProbe implements Queueable {
		public void execute(QueueableContext context) {
			asynchronousCalloutBodyLimit = new GoogleTransferLimitResolver().calloutBodyLimitBytes();
		}
	}

	@IsTest
	private static void testResolveLimitsPositiveKeepsTodaysSizesOnTheOldHeapLimit() {
		GoogleTransferLimitResolver.heapLimitOverride = HEAP_LIMIT_BEFORE_WINTER_27;

		GoogleTransferLimitDTO limits = new GoogleTransferLimitResolver().resolveLimits();

		Assert.areEqual(2097152L, limits.downloadChunkBytes, 'An org whose heap did not grow must keep exactly the chunk it had');
		Assert.areEqual(2097152L, limits.uploadChunkBytes);
		Assert.areEqual(2097152L, limits.largeFileThresholdBytes);
	}

	@IsTest
	private static void testResolveLimitsPositiveGrowsWithTheWinter27HeapLimit() {
		GoogleTransferLimitResolver.heapLimitOverride = HEAP_LIMIT_WINTER_27;

		GoogleTransferLimitDTO limits = new GoogleTransferLimitResolver().resolveLimits();

		Assert.areEqual(3670016L, limits.downloadChunkBytes, 'Downloads take two fifths of the free heap, aligned to the Drive chunk');
		Assert.areEqual(GoogleTransferLimitResolver.LIGHTNING_PAYLOAD_CHUNK_BYTES, limits.uploadChunkBytes, 'Uploads stop at what a Lightning request carries, not at the heap');
		Assert.areEqual(3670016L, limits.largeFileThresholdBytes);
	}

	@IsTest
	private static void testLargeFileThresholdBytesPositiveNeverBelowTheShippedDefault() {
		GoogleTransferLimitResolver.heapLimitOverride = 3000000;

		GoogleTransferLimitResolver resolver = new GoogleTransferLimitResolver();

		Assert.areEqual(786432L, resolver.downloadChunkBytes());
		Assert.areEqual(GoogleMetadataConfigService.DEFAULT_BIG_FILE_SIZE, resolver.largeFileThresholdBytes(), 'A smaller heap shrinks the chunks but never the threshold an org already relies on');
	}

	@IsTest
	private static void testResolveLimitsPositiveReadsTheRunningOrg() {
		GoogleTransferLimitResolver resolver = new GoogleTransferLimitResolver();
		Long runningHeapLimit = Limits.getLimitHeapSize();

		GoogleTransferLimitDTO limits = resolver.resolveLimits();

		Assert.areEqual(runningHeapLimit, resolver.heapLimitBytes());
		Assert.isTrue(limits.downloadChunkBytes > 0);
		Assert.areEqual(0L, Math.mod(limits.downloadChunkBytes, DRIVE_CHUNK_ALIGNMENT), 'Every chunk must be a multiple of what Google Drive accepts');
		Assert.areEqual(0L, Math.mod(limits.uploadChunkBytes, DRIVE_CHUNK_ALIGNMENT));
		Assert.isTrue(limits.uploadChunkBytes <= limits.downloadChunkBytes);
		Assert.isTrue(limits.uploadChunkBytes <= GoogleTransferLimitResolver.LIGHTNING_PAYLOAD_CHUNK_BYTES);
		Assert.isTrue(limits.largeFileThresholdBytes >= GoogleMetadataConfigService.DEFAULT_BIG_FILE_SIZE);
	}

	@IsTest
	private static void testCalloutBodyLimitBytesPositiveSynchronous() {
		Assert.areEqual(6000000L, new GoogleTransferLimitResolver().calloutBodyLimitBytes());
	}

	@IsTest
	private static void testCalloutBodyLimitBytesPositiveDoublesInTheBackground() {
		Test.startTest();
		System.enqueueJob(new CalloutLimitProbe());
		Test.stopTest();

		Assert.areEqual(12000000L, asynchronousCalloutBodyLimit, 'A background job may send twice what a request from a page may');
	}
}
