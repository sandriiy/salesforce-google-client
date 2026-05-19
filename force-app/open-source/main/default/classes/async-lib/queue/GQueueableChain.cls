/**
 * PMD False Positives:
 * - CognitiveComplexity: This was intended to have all the logic in one class
**/
@SuppressWarnings('PMD.CognitiveComplexity')
public inherited sharing class GQueueableChain {
    @TestVisible
    private List<GQueueableJob> jobs = new List<GQueueableJob>();
    @TestVisible
    private Id initialQueuableChainSchedulableId;
    private Boolean isChainedContext = false;
    private Integer chainCounter = 0;
    private GQueueableJob currentJob;

    public void execute(QueueableContext ctx) {
        GQueueableManager.get().setChain(this);
        attachQueueableChainFinalizer();
        executeCurrentJob(ctx);
    }

    public void attachQueueableChainFinalizer() {
        System.attachFinalizer(new GQueueableChainFinalizer(this));
    }

    public void executeCurrentJob(QueueableContext ctx) {
        if (!hasNextJob()) {
            return;
        }

        currentJob = getNextJobToProcess();
        currentJob.queueableCtx = ctx;
        currentJob.salesforceJobId = ctx.getJobId();
        currentJob.setChainCounterToName(++chainCounter);

        injectQueueableMockIfNeeded(currentJob);

        Savepoint sp = currentJob.rollbackOnJobExecuteFail ? Database.setSavepoint() : null;
        try {
            // Debug statements to determine the Job Id and Name
            System.debug(currentJob.customJobId);
            System.debug(currentJob.uniqueName);
            currentJob.work();
        } catch (Exception ex) {
            if (!currentJob.continueOnJobExecuteFail) {
                throw ex;
            }
            if (currentJob.rollbackOnJobExecuteFail) {
                Database.rollback(sp);
                Database.releaseSavepoint(sp);
            }
        }
    }

    public void enqueueNextJobIfAnyFromFinalizer(FinalizerContext ctx) {
        GQueueableJob previousJob = currentJob;
        previousJob.isProcessed = true;
        previousJob.finalizerCtx = ctx;

        setFinalizerContextToAllFinalizersForPreviousJob(previousJob, ctx);
        enqueueNextJobIfAny();
    }

    public void enqueueNextJobIfAny() {
        if (!hasNextJob() || (Test.isRunningTest() && System.isQueueable())) {
            return;
        }
        
        GQueueableJob nextJob = getNextJobToProcess();
        try {
            isChainedContext = true;
            nextJob.enqueue(this);
        } catch (Exception ex) {
            if (!nextJob.continueOnJobEnqueueFail) {
                throw ex;
            }
            isChainedContext = false;
            nextJob.isProcessed = true;
            enqueueNextJobIfAny();
        }
    }

    public Boolean hasNextJob() {
        return getNextJobToProcess() != null;
    }

    public void addJob(GQueueableJob job) {
        job.setMainAttributes();
        jobs.add(job);
        jobs.sort();
    }

    public List<GQueueableJob> getJobs() {
        return jobs;
    }

    public void executeOrReplaceInitialQueueableChainSchedulableJob() {
        GQueueableChainSchedulable.removeInitialQueuableChainSchedulableIfExists(initialQueuableChainSchedulableId);

        Datetime nextRunTime = Datetime.now().addMinutes(1);
        String hour = String.valueOf(nextRunTime.hour());
        String min = String.valueOf(nextRunTime.minute());
        String ss = String.valueOf(nextRunTime.second());
        String nextFireTime = ss + ' ' + min + ' ' + hour + ' * * ?';

        initialQueuableChainSchedulableId = System.schedule('GQueueableChainSchedulable/' + String.valueOf(Datetime.now()) + '/' + UUID.randomUUID().toString(), nextFireTime, new GQueueableChainSchedulable(this));
    }

    public GQueueableJob getCurrentJob() {
        return currentJob;
    }

    public Boolean isChainedContext() {
        return isChainedContext;
    }

    public Id getQueueableChainSchedulableId() {
        return initialQueuableChainSchedulableId;
    }

    private GQueueableJob getNextJobToProcess() {
        for (GQueueableJob job : jobs) {
            if (!job.isProcessed) {
                return job;
            }
        }
        return null;
    }

    private void setFinalizerContextToAllFinalizersForPreviousJob(GQueueableJob previousJob, FinalizerContext ctx) {
        for (GQueueableJob job : jobs) {
            if (!job.isProcessed && job.parentCustomJobId == previousJob.customJobId && job.finalizerCtx == null) {
                injectFinalizerMockOrDefault(job, ctx);
            }
        }
    }

    private void injectQueueableMockIfNeeded(GQueueableJob job) {
        if (Test.isRunningTest() && GAsyncMock.hasQueueableMock(job.mockId)) {
            job.queueableCtx = GAsyncMock.getQueueableContext(job.mockId);
        }
    }

    private void injectFinalizerMockOrDefault(GQueueableJob job, FinalizerContext defaultCtx) {
        if (Test.isRunningTest() && GAsyncMock.hasFinalizerMock(job.mockId)) {
            job.finalizerCtx = GAsyncMock.getFinalizerContext(job.mockId);
            return;
        }
        job.finalizerCtx = defaultCtx;
    }
}
