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
public without sharing class GoogleCacheDriveFolderService {
	@TestVisible
	private static final String KEY_PREFIX = 'GFOLDER1';
	@TestVisible
	private static final String PENDING_PREFIX = 'PENDING';
	@TestVisible
	private static final Long PENDING_LIFESPAN_MILLISECONDS = 60000L;

	@TestVisible
	private static IGoogleCacheProvider cacheProviderOverride;

	private IGoogleCacheProvider cacheProvider;
	private Boolean isCacheProviderResolved = false;

	public String buildFolderKey(String parentFolderId, Id targetId) {
		if (String.isBlank(parentFolderId) || targetId == null) return null;

		String rawKey = parentFolderId + ':' + String.valueOf(targetId);
		String hashedKey = EncodingUtil.convertToHex(Crypto.generateDigest('SHA1', Blob.valueOf(rawKey))).substring(0, 32);

		return KEY_PREFIX + hashedKey;
	}

	public String getFolderId(String folderKey) {
		String storedValue = read(folderKey);
		if (String.isBlank(storedValue) || isPendingValue(storedValue)) return null;

		return storedValue;
	}

	public Boolean isPending(String folderKey) {
		String storedValue = read(folderKey);
		if (!isPendingValue(storedValue)) return false;

		return !hasPendingExpired(storedValue);
	}

	public void markPending(String folderKey) {
		write(folderKey, PENDING_PREFIX + ':' + String.valueOf(DateTime.now().getTime()));
	}

	public void putFolderId(String folderKey, String folderId) {
		if (String.isBlank(folderId)) return;
		write(folderKey, folderId);
	}

	public void evict(String folderKey) {
		if (String.isBlank(folderKey)) return;

		try {
			IGoogleCacheProvider resolvedCache = resolveCacheProvider();
			if (resolvedCache == null) return;

			resolvedCache.remove(folderKey);
		} catch (Exception ex) {
			Logger.info(
				'Folder Cache Unavailable --> Operation=evict, Error=' + ex.getMessage()
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}
	}

	private String read(String folderKey) {
		if (String.isBlank(folderKey)) return null;

		try {
			IGoogleCacheProvider resolvedCache = resolveCacheProvider();
			if (resolvedCache == null) return null;

			Object storedValue = resolvedCache.get(folderKey);
			return storedValue == null ? null : String.valueOf(storedValue);
		} catch (Exception ex) {
			Logger.info(
				'Folder Cache Unavailable --> Operation=read, Error=' + ex.getMessage()
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			return null;
		}
	}

	private void write(String folderKey, String value) {
		if (String.isBlank(folderKey)) return;

		try {
			IGoogleCacheProvider resolvedCache = resolveCacheProvider();
			if (resolvedCache == null) return;

			resolvedCache.put(folderKey, value);
		} catch (Exception ex) {
			Logger.info(
				'Folder Cache Unavailable --> Operation=write, Error=' + ex.getMessage()
			).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		}
	}

	private Boolean isPendingValue(String storedValue) {
		return String.isNotBlank(storedValue) && storedValue.startsWith(PENDING_PREFIX + ':');
	}

	private Boolean hasPendingExpired(String storedValue) {
		String claimedAt = storedValue.substringAfter(':');
		if (!claimedAt.isNumeric()) return true;

		Long elapsedMilliseconds = DateTime.now().getTime() - Long.valueOf(claimedAt);
		return elapsedMilliseconds > PENDING_LIFESPAN_MILLISECONDS;
	}

	private IGoogleCacheProvider resolveCacheProvider() {
		if (isCacheProviderResolved) return cacheProvider;

		isCacheProviderResolved = true;
		cacheProvider = cacheProviderOverride != null
			? cacheProviderOverride
			: (IGoogleCacheProvider) new GoogleOrgCacheProvider(GoogleCacheConfigService.PARTITION);

		return cacheProvider;
	}
}
