public inherited sharing class GAsync {
    public static GQueueableBuilder queueable(GQueueableJob job) {
        return new GQueueableBuilder(job);
    }

    public static GQueueableBuilder queueable() {
        return new GQueueableBuilder();
    }

    public static GBatchableBuilder batchable(Object job) {
        return new GBatchableBuilder(job);
    }

    public static GSchedulableBuilder schedulable(Schedulable scheduleJob) {
        return new GSchedulableBuilder(scheduleJob);
    }

    public static QueueableJobContext getQueueableJobContext() {
        return GQueueableManager.get().getQueueableJobContext();
    }

    public static Id getQueueableChainSchedulableId() {
        return GQueueableManager.get().getQueueableChainSchedulableId();
    }

    public static QueueableChainState getCurrentQueueableChainState() {
        return new QueueableChainState().setCurrentQueueableChainState();
    }

    public class QueueableJobContext {
        public GQueueableJob currentJob;
        public QueueableContext queueableCtx {
            get {
                return currentJob.queueableCtx;
            }
        }
        public FinalizerContext finalizerCtx {
            get {
                return currentJob.finalizerCtx;
            }
        }
    }

    public class Result {
        public Id salesforceJobId;
        public AsyncType asyncType;
        public String customJobId;
        public QueueableChainState queueableChainState;
        public GQueueableJob job;

        public Result(Id salesforceJobId) {
            this.salesforceJobId = salesforceJobId;
        }

        public Result(GQueueableJob job) {
            this.asyncType = GAsync.AsyncType.QUEUEABLE;
            this.salesforceJobId = job.salesforceJobId;
            this.customJobId = job.customJobId;
            this.job = job;
        }

        public Result setAsyncType(AsyncType asyncType) {
            this.asyncType = asyncType;
            return this;
        }

        public Result setQueueableChainState(QueueableChainState queueableChainState) {
            this.queueableChainState = queueableChainState;
            return this;
        }

        public Result setCurrentQueueableChainState() {
            this.queueableChainState = new QueueableChainState().setCurrentQueueableChainState();
            return this;
        }
    }

    public class QueueableChainState {
        public List<GQueueableJob> jobs;
        public Id nextSalesforceJobId;
        public String nextCustomJobId;
        public GQueueableManager.EnqueueType enqueueType;

        public QueueableChainState setCurrentQueueableChainState() {
            GQueueableChain chain = GQueueableManager.get().getChain();
            setJobs(chain.getJobs());
            setNextCustomJobIdFromFirstJob();
            setNextSalesforceJobIdFromFirstJob();
            return this;
        }

        public QueueableChainState setJobs(List<GQueueableJob> jobs) {
            this.jobs = jobs;
            return this;
        }

        public QueueableChainState setNextSalesforceJobIdFromFirstJob() {
            if (jobs == null || jobs.isEmpty()) {
                return this;
            }
            return setNextSalesforceJobId(jobs.get(0).salesforceJobId);
        }

        public QueueableChainState setNextSalesforceJobId(Id jobId) {
            this.nextSalesforceJobId = jobId;
            return this;
        }

        public QueueableChainState setNextCustomJobIdFromFirstJob() {
            if (jobs == null || jobs.isEmpty()) {
                return this;
            }
            this.nextCustomJobId = jobs.get(0).customJobId;
            return this;
        }

        public QueueableChainState setEnqueueType(GQueueableManager.EnqueueType enqueueType) {
            this.enqueueType = enqueueType;
            return this;
        }
    }

    public enum AsyncType {
        QUEUEABLE,
        BATCHABLE,
        SCHEDULABLE
    }

    public class IllegalArgumentException extends Exception {
    }
}
