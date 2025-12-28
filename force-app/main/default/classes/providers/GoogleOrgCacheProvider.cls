public with sharing class GoogleOrgCacheProvider implements IGoogleCacheProvider {
	private final Cache.OrgPartition partition;

	public GoogleOrgCacheProvider(String partitionName) {
		this.partition = Cache.Org.getPartition(partitionName);
	}

	public void put(String key, String value) {
		partition.put(key, value);
	}

	public Object get(String key) {
		return partition.get(key);
	}

	public void remove(String key) {
		partition.remove(key);
	}

	public Cache.SessionPartition getSessionPartition() {
		return null;
	}

	public Cache.OrgPartition getOrgPartition() {
		return partition;
	}
}