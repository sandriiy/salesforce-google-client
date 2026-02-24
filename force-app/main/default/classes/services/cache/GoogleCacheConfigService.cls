public inherited sharing class GoogleCacheConfigService {
	public class GoogleCacheConfigException extends Exception {}

	public static final String PARTITION = 'GoogleCloudClient';

	private static final String PREFIX_CONFIG = 'CFG';
	private static final String PREFIX_KV = 'KV';
	private final IGoogleCacheProvider cache;

	public GoogleCacheConfigService() {
		this(new GoogleSessionCacheProvider(PARTITION));
	}

	public GoogleCacheConfigService(IGoogleCacheProvider injectedCache) {
		this.cache = (injectedCache == null)
			? (IGoogleCacheProvider) new GoogleSessionCacheProvider(PARTITION)
			: injectedCache;
	}

	public Cache.SessionPartition getSessionPartition() {
		return cache.getSessionPartition();
	}

	public Cache.OrgPartition getOrgPartition() {
		return cache.getOrgPartition();
	}

	public void put(String key, String value) {
		validateKey(key);

		if (value == null) {
			throw new GoogleCacheConfigException('Cache Value cannot be null');
		}

		add(buildKvKey(key), value);
	}

	public String get(String key) {
		validateKey(key);
		return read(buildKvKey(key));
	}

	public void remove(String key) {
		validateKey(key);
		deleteKey(buildKvKey(key));
	}

	public String generateConfigId() {
		Long ts = DateTime.now().getTime();
		String rnd = EncodingUtil.convertToHex(
			Crypto.generateDigest('SHA1', Blob.valueOf(String.valueOf(Math.random()) + ':' + String.valueOf(ts)))
		).substring(0, 8).toLowerCase();

		return 'cfg_' + String.valueOf(ts) + '_' + rnd;
	}

	public Boolean isValidConfigId(String configId) {
		if (String.isBlank(configId)) return false;
		return Pattern.matches('^cfg_\\d+_[0-9a-f]{8}$', configId);
	}

	public void putConfig(String configId, String payloadJson) {
		validateConfigId(configId);

		if (payloadJson == null) {
			throw new GoogleCacheConfigException('Payload cannot be null');
		}

		add(buildConfigKey(configId), payloadJson);
	}

	public String getConfig(String configId) {
		validateConfigId(configId);
		return read(buildConfigKey(configId));
	}

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