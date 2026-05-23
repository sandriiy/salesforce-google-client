public inherited sharing class GBatchableManager {
    public static final Integer DEFAULT_BATCH_SIZE = 200;

    private static GBatchableManager instance;

    public GAsync.Result execute(GBatchableBuilder builder) {
        if (builder == null || builder.job == null) {
            throw new IllegalArgumentException('Batch job must be set.');
        }

        Id jobId = Database.executeBatch(builder.job, builder.scopeSize ?? DEFAULT_BATCH_SIZE);

        return new GAsync.Result(jobId)
            .setAsyncType(GAsync.AsyncType.BATCHABLE);
    }

    public static GBatchableManager get() {
        if (instance == null) {
            instance = new GBatchableManager();
        }
        return instance;
    }
}
