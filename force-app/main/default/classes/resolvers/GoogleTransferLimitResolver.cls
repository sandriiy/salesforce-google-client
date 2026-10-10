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
/**
 * Sizes every request that carries file content through the Apex heap from the heap limit of the running
 * org, so the same package moves as much per request as the Salesforce release allows and nothing has to
 * be configured when that limit grows. Every chunk is aligned to what Google Drive accepts in a resumable
 * upload, and the upload chunk is additionally held under what one Lightning request can carry, which no
 * heap limit changes.
 */
public without sharing class GoogleTransferLimitResolver {
	/**
	 * The most the browser may send through Apex in one request. Its base64 form, once URL encoded, has to
	 * stay under the 4 MB a Lightning request carries, whatever the heap would allow.
	 */
	public static final Long LIGHTNING_PAYLOAD_CHUNK_BYTES = 2621440L;

	private static final Long SYNCHRONOUS_CALLOUT_BODY_LIMIT_BYTES = 6000000L;
	private static final Long ASYNCHRONOUS_CALLOUT_BODY_LIMIT_BYTES = 12000000L;
	private static final Long HEAP_RESERVE_BYTES = 524288L;
	private static final Long HEAP_SHARE_PER_CHUNK_NUMERATOR = 2L;
	private static final Long HEAP_SHARE_PER_CHUNK_DENOMINATOR = 5L;

	@TestVisible
	private static Integer heapLimitOverride;

	/**
	 * The heap limit of the running transaction, which every other size here is derived from.
	 *
	 * @return The limit in bytes.
	 */
	public Long heapLimitBytes() {
		return heapLimitOverride != null ? heapLimitOverride : Limits.getLimitHeapSize();
	}

	/**
	 * How many bytes one download request may carry back to the browser. The bytes are held once as the
	 * Drive answer and again as their base64 text, so the chunk takes two fifths of the heap left after a
	 * reserve, aligned down to the Drive chunk size.
	 *
	 * @return The chunk size in bytes.
	 */
	public Long downloadChunkBytes() {
		return alignDown((heapLimitBytes() - HEAP_RESERVE_BYTES) * HEAP_SHARE_PER_CHUNK_NUMERATOR / HEAP_SHARE_PER_CHUNK_DENOMINATOR);
	}

	/**
	 * How many bytes one upload request may bring from the browser: the download chunk, held under what a
	 * Lightning request may carry.
	 *
	 * @return The chunk size in bytes.
	 */
	public Long uploadChunkBytes() {
		return Math.min(downloadChunkBytes(), LIGHTNING_PAYLOAD_CHUNK_BYTES);
	}

	/**
	 * The size above which a file counts as large when no size is configured. It is never below the shipped
	 * default, so an org whose heap did not grow keeps exactly what it had.
	 *
	 * @return The threshold in bytes.
	 */
	public Long largeFileThresholdBytes() {
		return Math.max(GoogleMetadataConfigService.DEFAULT_BIG_FILE_SIZE, downloadChunkBytes());
	}

	/**
	 * The most a single callout may send or receive in the running context, which a background job gets
	 * twice as much of as a request from a page.
	 *
	 * @return The limit in bytes.
	 */
	public Long calloutBodyLimitBytes() {
		Boolean isAsynchronous = System.isBatch() || System.isQueueable() || System.isFuture() || System.isScheduled();
		return isAsynchronous ? ASYNCHRONOUS_CALLOUT_BODY_LIMIT_BYTES : SYNCHRONOUS_CALLOUT_BODY_LIMIT_BYTES;
	}

	/**
	 * Everything the browser needs to size its requests.
	 *
	 * @return The chunk sizes and the large file threshold.
	 */
	public GoogleTransferLimitDTO resolveLimits() {
		GoogleTransferLimitDTO limits = new GoogleTransferLimitDTO();
		limits.uploadChunkBytes = uploadChunkBytes();
		limits.downloadChunkBytes = downloadChunkBytes();
		limits.largeFileThresholdBytes = largeFileThresholdBytes();
		return limits;
	}

	private Long alignDown(Long bytes) {
		return (bytes / GoogleCloudConstants.DRIVE_CHUNK_ALIGNMENT_BYTES) * GoogleCloudConstants.DRIVE_CHUNK_ALIGNMENT_BYTES;
	}
}
