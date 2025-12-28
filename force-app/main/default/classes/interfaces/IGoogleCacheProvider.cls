public interface IGoogleCacheProvider {
	void put(String key, String value);
	Object get(String key);
	void remove(String key);
	Cache.SessionPartition getSessionPartition();
	Cache.OrgPartition getOrgPartition();
}