public inherited sharing class GQueueableBuilder {
    private GQueueableJob job;

    public GQueueableBuilder(GQueueableJob job) {
        this.job = job.clone();
    }

    public GQueueableBuilder() {
    }

    public GQueueableBuilder asyncOptions(AsyncOptions asyncOptions) {
        if (job.delay != null) {
            throw new IllegalArgumentException(
                GQueueableManager.ERROR_MESSAGE_ASYNC_OPTIONS_AFTER_DELAY
            );
        }
        job.asyncOptions = asyncOptions;
        return this;
    }

    public GQueueableBuilder delay(Integer delay) {
        if (job.asyncOptions != null) {
            throw new IllegalArgumentException(
                GQueueableManager.ERROR_MESSAGE_DELAY_AFTER_ASYNC_OPTIONS
            );
        }
        job.delay = delay;
        return this;
    }

    public GQueueableBuilder priority(Integer priority) {
        job.priority = priority;
        return this;
    }

    public GQueueableBuilder continueOnJobEnqueueFail() {
        job.continueOnJobEnqueueFail = true;
        return this;
    }

    public GQueueableBuilder continueOnJobExecuteFail() {
        job.continueOnJobExecuteFail = true;
        return this;
    }

    public GQueueableBuilder rollbackOnJobExecuteFail() {
        job.rollbackOnJobExecuteFail = true;
        return this;
    }

    // Clones job with all complex class members, removing all references from original job
    // Stored on job, for further reference
    public GQueueableBuilder deepClone() {
        job.deepClone = true;
        return this;
    }

    public GQueueableBuilder mockId(String mockId) {
        job.mockId = mockId;
        return this;
    }

    public GQueueableBuilder chain(GQueueableJob job) {
        if (this.job != null) {
            chain();
        }
        this.job = job;
        return this;
    }

    public GSchedulableBuilder asSchedulable() {
        return new GSchedulableBuilder(this);
    }

    public GAsync.Result chain() {
        return GQueueableManager.get().chain(job);
    }

    public GAsync.Result attachFinalizer() {
        return GQueueableManager.get().attachFinalizer(job);
    }

    public GAsync.Result enqueue() {
        if (this.job == null) {
            return new GAsync.Result((Id) null)
                .setQueueableChainState(
                    new GAsync.QueueableChainState().setJobs(new List<GQueueableJob>())
                );
        }
        return GQueueableManager.get().chainAndEnqueue(job);
    }
}
