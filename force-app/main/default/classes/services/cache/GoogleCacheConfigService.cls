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
 * Wraps the platform cache partition this package uses, for the OAuth token and for handing
 * configuration between the setup window and the page that opened it. Keys are sanitised because the
 * platform only accepts letters and digits in them.
 */
public inherited sharing class GoogleCacheConfigService {
	public class GoogleCacheConfigException extends Exception {}

	/**
	 * The partition this package owns. Its allocation ships at one unit of org and one of session, which is
	 * what a Developer Edition or scratch org can spare.
	 */
	public static final String PARTITION = 'GoogleCloudClient';

	private static final String PREFIX_CONFIG = 'CFG';
	private static final String PREFIX_KV = 'KV';
	private final IGoogleCacheProvider cache;

	public GoogleCacheConfigService() {
		this(new GoogleSessionCacheProvider(PARTITION));
	}

	/**
	 * Builds the service on a cache of your choosing, which is how the org partition is used instead of the
	 * session one.
	 *
	 * @param injectedCache The cache to use. A null gets the session partition.
	 */
	public GoogleCacheConfigService(IGoogleCacheProvider injectedCache) {
		this.cache = (injectedCache == null)
			? (IGoogleCacheProvider) new GoogleSessionCacheProvider(PARTITION)
			: injectedCache;
	}

	/**
	 * The session partition, for a caller that hands it to a library.
	 *
	 * @return The partition, or null when this service is on the org cache.
	 */
	public Cache.SessionPartition getSessionPartition() {
		return cache.getSessionPartition();
	}

	/**
	 * The org partition, for a caller that hands it to a library.
	 *
	 * @return The partition, or null when this service is on the session cache.
	 */
	public Cache.OrgPartition getOrgPartition() {
		return cache.getOrgPartition();
	}

	/**
	 * Stores a value under a key of your own.
	 *
	 * @param key Your key, at most 120 characters.
	 * @param value The value to store, which cannot be null.
	 */
	public void put(String key, String value) {
		validateKey(key);

		if (value == null) {
			throw new GoogleCacheConfigException('Cache Value cannot be null');
		}

		add(buildKvKey(key), value);
	}

	/**
	 * Reads back a value stored under a key of your own.
	 *
	 * @param key Your key.
	 * @return The value, or null when nothing is there.
	 */
	public String get(String key) {
		validateKey(key);
		return read(buildKvKey(key));
	}

	/**
	 * Drops a value stored under a key of your own.
	 *
	 * @param key Your key.
	 */
	public void remove(String key) {
		validateKey(key);
		deleteKey(buildKvKey(key));
	}

	/**
	 * Makes the one time id the setup window and its opener use to find each other.
	 *
	 * @return A fresh configuration id.
	 */
	public String generateConfigId() {
		Long ts = DateTime.now().getTime();
		String rnd = EncodingUtil.convertToHex(
			Crypto.generateDigest('SHA1', Blob.valueOf(String.valueOf(Math.random()) + ':' + String.valueOf(ts)))
		).substring(0, 8).toLowerCase();

		return 'cfg_' + String.valueOf(ts) + '_' + rnd;
	}

	/**
	 * Checks that an id really is one this service made, since it arrives from the browser.
	 *
	 * @param configId The id to check.
	 * @return True when the shape is right.
	 */
	public Boolean isValidConfigId(String configId) {
		if (String.isBlank(configId)) return false;
		return Pattern.matches('^cfg_\\d+_[0-9a-f]{8}$', configId);
	}

	/**
	 * Puts the configuration payload where the other window can pick it up.
	 *
	 * @param configId The id the two sides agreed on.
	 * @param payloadJson The payload, which cannot be null.
	 */
	public void putConfig(String configId, String payloadJson) {
		validateConfigId(configId);

		if (payloadJson == null) {
			throw new GoogleCacheConfigException('Payload cannot be null');
		}

		add(buildConfigKey(configId), payloadJson);
	}

	/**
	 * Picks up a configuration payload the other window left.
	 *
	 * @param configId The id the two sides agreed on.
	 * @return The payload, or null when it is not there yet.
	 */
	public String getConfig(String configId) {
		validateConfigId(configId);
		return read(buildConfigKey(configId));
	}

	/**
	 * Clears a configuration payload once it has been read.
	 *
	 * @param configId The id the two sides agreed on.
	 */
	public void removeConfig(String configId) {
		validateConfigId(configId);
		deleteKey(buildConfigKey(configId));
	}

	private String buildKvKey(String key) {
		return PREFIX_KV + sanitizeKey(key);
	}

	private String buildConfigKey(String configId) {
		return PREFIX_CONFIG + sanitizeKey(configId);
	}

	private String sanitizeKey(String raw) {
		String v = String.valueOf(raw).trim();
		v = v.replaceAll('[^A-Za-z0-9]', '');
		return v;
	}

	private void validateKey(String key) {
		if (String.isBlank(key)) {
			throw new GoogleCacheConfigException('Cache Key is required');
		}

		if (key.length() > 120) {
			throw new GoogleCacheConfigException('Cache Key is too long');
		}
	}

	private void validateConfigId(String configId) {
		if (!isValidConfigId(configId)) {
			throw new GoogleCacheConfigException('Invalid configId format');
		}
	}

	private void add(String fullKey, String value) {
		try {
			if (String.isBlank(fullKey)) {
				throw new GoogleCacheConfigException('Invalid cache key');
			}

			cache.put(fullKey, value);
		} catch (Exception e) {
			throw buildCacheAccessException(e);
		}
	}

	private String read(String fullKey) {
		try {
			if (String.isBlank(fullKey)) {
				return null;
			}

			Object v = cache.get(fullKey);
			return (v == null) ? null : String.valueOf(v);
		} catch (Exception e) {
			throw buildCacheAccessException(e);
		}
	}

	private void deleteKey(String fullKey) {
		try {
			if (String.isBlank(fullKey)) {
				return;
			}

			cache.remove(fullKey);
		} catch (Exception e) {
			throw buildCacheAccessException(e);
		}
	}

	private GoogleCacheConfigException buildCacheAccessException(Exception e) {
		return new GoogleCacheConfigException(
			'Unable to access Platform Cache partition "' + PARTITION + '": ' + e.getMessage()
		);
	}
}