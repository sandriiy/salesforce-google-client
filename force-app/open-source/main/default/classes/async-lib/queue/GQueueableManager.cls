public inherited sharing class GQueueableManager {
    public static final String ERROR_MESSAGE_ASYNC_OPTIONS_AFTER_DELAY = 'Cannot set asyncOptions after delay has been set';
    public static final String ERROR_MESSAGE_DELAY_AFTER_ASYNC_OPTIONS = 'Cannot set delay after asyncOptions has been set';
    private static final String ERROR_MESSAGE_CHAIN_NULL = 'GQueueableChain cannot be null';
    private static final String ERROR_MESSAGE_NO_JOB_SET = 'No Queueable job has been set to enqueue';
    private static final String ERROR_MESSAGE_FINALIZER_JOB_NOT_SET = 'No Finalizer job has been set to attach finalizer';
    @TestVisible
    private static final String ERROR_MESSAGE_CANNOT_ATTACH_FINALIZER = 'Cannot attach finalizer when not in a GQueueableChain context';
    @TestVisible
    private static final String ERROR_MESSAGE_CANNOT_ENQUEUE_FINALIZER_DIRECTLY = 'Cannot enqueue a GQueueableJob.Finalizer directly. Use attachFinalizer() instead.';
    @TestVisible
    private static final String ERROR_MESSAGE_FINALIZER_JOB_MUST_EXTEND_FINALIZER = 'Finalizer job must extend GQueueableJob.Finalizer';

    private static GQueueableManager instance;

    private GQueueableChain chain = new GQueueableChain();

    // Should only be used by GQueueableChain to set the chain in the context
    public void setChain(GQueueableChain chain) {
        if (chain == null) {
            throw new IllegalArgumentException(ERROR_MESSAGE_CHAIN_NULL);
        }
        this.chain = chain;
    }

    public GQueueableChain getChain() {
        return chain;
    }

    public GAsync.QueueableJobContext getQueueableJobContext() {
        GAsync.QueueableJobContext ctx = new GAsync.QueueableJobContext();
        ctx.currentJob = chain.getCurrentJob();
        return ctx;
    }

    public Id getQueueableChainSchedulableId() {
        return chain.getQueueableChainSchedulableId();
    }

    public GAsync.Result attachFinalizer(GQueueableJob job) {
        if (job == null) {
            throw new IllegalArgumentException(ERROR_MESSAGE_FINALIZER_JOB_NOT_SET);
        }

        if (!chain.isChainedContext()) {
            throw new IllegalArgumentException(ERROR_MESSAGE_CANNOT_ATTACH_FINALIZER);
        }

        GQueueableJob currentJobInChainContact = chain.getCurrentJob();
        job.parentCustomJobId = currentJobInChainContact.customJobId;

        return chain(job);
    }

    public GAsync.Result chainAndEnqueue(GQueueableJob job) {
        GAsync.Result result = chain(job);
        return enqueue(result.job);
    }

    public GAsync.Result chain(GQueueableJob job) {
        if (job == null) {
            throw new IllegalArgumentException(ERROR_MESSAGE_NO_JOB_SET);
        }
        if (!job.isFinalizer && job instanceof GQueueableJob.Finalizer) {
            throw new IllegalArgumentException(ERROR_MESSAGE_CANNOT_ENQUEUE_FINALIZER_DIRECTLY);
        }
        if (job.isFinalizer && !(job instanceof GQueueableJob.Finalizer)) {
            throw new IllegalArgumentException(ERROR_MESSAGE_FINALIZER_JOB_MUST_EXTEND_FINALIZER);
        }

        GQueueableJob clonedJob = job.cloneJob();
        chain.addJob(clonedJob);
        return new GAsync.Result(clonedJob).setCurrentQueueableChainState();
    }

    public GAsync.Result enqueue(GQueueableJob job) {
        GAsync.QueueableChainState queueableChainState = new GAsync.QueueableChainState()
            .setJobs(chain.getJobs())
            .setNextCustomJobIdFromFirstJob();

        Id enqueuedJobId;

        if (shouldExecuteOrReplaceInitialQueueableChainSchedulable()) {
            chain.executeOrReplaceInitialQueueableChainSchedulableJob();
            enqueuedJobId = chain.getQueueableChainSchedulableId();
            queueableChainState
                .setNextSalesforceJobId(enqueuedJobId)
                .setEnqueueType(EnqueueType.INITIAL_QUEUEABLE_CHAIN_SCHEDULABLE);
        } else if (!chain.isChainedContext()) {
            chain.enqueueNextJobIfAny();
            queueableChainState
                .setNextSalesforceJobIdFromFirstJob()
                .setEnqueueType(EnqueueType.NEW_CHAIN);
            List<GQueueableJob> jobsAfterEnqueue = chain.getJobs();
            if (jobsAfterEnqueue != null && !jobsAfterEnqueue.isEmpty()) {
                enqueuedJobId = jobsAfterEnqueue.get(0).salesforceJobId;
            }
            chain = new GQueueableChain();
        } else {
            queueableChainState.setEnqueueType(EnqueueType.EXISTING_CHAIN);
            enqueuedJobId = job.salesforceJobId;
        }

        GAsync.Result result = new GAsync.Result(job).setQueueableChainState(queueableChainState);
        if (enqueuedJobId != null) {
            result.salesforceJobId = enqueuedJobId;
        }
        return result;
    }

    private Boolean shouldExecuteOrReplaceInitialQueueableChainSchedulable() {
        return !chain.isChainedContext() &&
            (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs() || System.isQueueable());
    }

    public static GQueueableManager get() {
        if (instance == null) {
            instance = new GQueueableManager();
        }
        return instance;
    }

    public enum EnqueueType {
        INITIAL_QUEUEABLE_CHAIN_SCHEDULABLE,
        NEW_CHAIN,
        EXISTING_CHAIN
    }
}
