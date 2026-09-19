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
 * Remembers which Drive folder belongs to which record, in the org cache. Drive search does not reliably
 * return a folder that was just created, which is how records ended up with two folders, and this closes
 * that gap. It is only ever an optimisation: every cache failure is treated as a miss, so with no cache
 * allocated the behaviour falls back to searching Drive. Never make a folder path depend on a value
 * coming back from here.
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

	/**
	 * Makes the cache key for a folder, which is a hash because the platform only accepts letters and digits
	 * in a key.
	 *
	 * @param parentFolderId The folder it lives under.
	 * @param targetId The user or record the folder belongs to.
	 * @return The key to read and write with, or null when either part is missing.
	 */
	public String buildFolderKey(String parentFolderId, Id targetId) {
		if (String.isBlank(parentFolderId) || targetId == null) return null;

		String rawKey = parentFolderId + ':' + String.valueOf(targetId);
		String hashedKey = EncodingUtil.convertToHex(Crypto.generateDigest('SHA1', Blob.valueOf(rawKey))).substring(0, 32);

		return KEY_PREFIX + hashedKey;
	}

	/**
	 * Reads a remembered folder. A folder another transaction is still creating reads as a miss.
	 *
	 * @param folderKey The key from buildFolderKey().
	 * @return The folder Id, or null when it is not known yet.
	 */
	public String getFolderId(String folderKey) {
		String storedValue = read(folderKey);
		if (String.isBlank(storedValue) || isPendingValue(storedValue)) return null;

		return storedValue;
	}

	/**
	 * Says whether another transaction is creating this folder right now, so the caller defers instead of
	 * creating a second one. A claim older than a minute is treated as abandoned.
	 *
	 * @param folderKey The key from buildFolderKey().
	 * @return True while somebody else is creating it.
	 */
	public Boolean isPending(String folderKey) {
		String storedValue = read(folderKey);
		if (!isPendingValue(storedValue)) return false;

		return !hasPendingExpired(storedValue);
	}

	/**
	 * Claims the folder before creating it, so other transactions wait rather than duplicate it.
	 *
	 * @param folderKey The key from buildFolderKey().
	 */
	public void markPending(String folderKey) {
		write(folderKey, PENDING_PREFIX + ':' + String.valueOf(DateTime.now().getTime()));
	}

	/**
	 * Remembers a folder that has been created or found.
	 *
	 * @param folderKey The key from buildFolderKey().
	 * @param folderId The Drive folder to remember.
	 */
	public void putFolderId(String folderKey, String folderId) {
		if (String.isBlank(folderId)) return;
		write(folderKey, folderId);
	}

	/**
	 * Forgets a folder, which is what to do when a Drive call against it fails so the next transaction looks
	 * it up again instead of trusting a stale Id.
	 *
	 * @param folderKey The key from buildFolderKey().
	 */
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
