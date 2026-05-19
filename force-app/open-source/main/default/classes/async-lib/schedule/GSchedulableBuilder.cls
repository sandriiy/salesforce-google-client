public inherited sharing class GSchedulableBuilder {
    public Schedulable scheduleJob;
    public GBatchableBuilder batchableBuilder;

    public String name;
    public List<GCronBuilder> crons = new List<GCronBuilder>();
    public Boolean skipWhenAlreadyScheduled = false;

    public GSchedulableBuilder(GQueueableBuilder builder) {
        this.scheduleJob = new GQueueableSchedulable(builder);
    }

    public GSchedulableBuilder(GBatchableBuilder builder) {
        this.batchableBuilder = builder;
        this.scheduleJob = new GBatchableSchedulable(builder);
    }

    public GSchedulableBuilder(Schedulable scheduleJob) {
        this.scheduleJob = scheduleJob;
    }

    public GSchedulableBuilder name(String name) {
        this.name = name;
        return this;
    }

    public GSchedulableBuilder cronExpression(String cronExpression) {
        return cronExpression(new GCronBuilder(cronExpression));
    }

    public GSchedulableBuilder cronExpression(GCronBuilder builder) {
        return cronExpression(new List<GCronBuilder>{ builder });
    }

    public GSchedulableBuilder cronExpression(List<GCronBuilder> builders) {
        this.crons.addAll(builders);
        return this;
    }

    public GSchedulableBuilder skipWhenAlreadyScheduled() {
        this.skipWhenAlreadyScheduled = true;
        return this;
    }

    public List<GAsync.Result> schedule() {
        return GSchedulableManager.get().schedule(this);
    }
}
