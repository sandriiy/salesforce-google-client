public inherited sharing class GBatchableBuilder {
    public Database.Batchable<Object> job;
    public Integer scopeSize;
    public Integer minutesFromNow;

    public GBatchableBuilder(Object job) {
        this.job = (Database.Batchable<Object>) job;
    }

    public GBatchableBuilder scopeSize(Integer scopeSize) {
        if (scopeSize <= 0) {
            throw new IllegalArgumentException('Scope size must be greater than zero.');
        }
        this.scopeSize = scopeSize;
        return this;
    }

    public GBatchableBuilder minutesFromNow(Integer minutes) {
        if (minutes <= 0) {
            throw new IllegalArgumentException('Minutes from now must be greater than zero.');
        }
        this.minutesFromNow = minutes;
        return this;
    }

    public GSchedulableBuilder asSchedulable() {
        return new GSchedulableBuilder(this);
    }

    public GAsync.Result execute() {
        return GBatchableManager.get().execute(this);
    }
}
