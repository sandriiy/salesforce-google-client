@SuppressWarnings('PMD.ExcessivePublicCount')
public abstract class GQueueableJob implements Queueable, Comparable {
    public Id salesforceJobId;
    public String customJobId;
    public String className {
        get {
            return getFullClassName(this);
        }
        private set;
    }
    public String uniqueName;
    public Integer delay;
    public Integer priority;
    public AsyncOptions asyncOptions;
    public Boolean isProcessed = false;
    public Boolean continueOnJobEnqueueFail = false;
    public Boolean continueOnJobExecuteFail = false;
    public Boolean rollbackOnJobExecuteFail = false;
    public Boolean deepClone = false;
    public QueueableContext queueableCtx;

    public String parentCustomJobId;
    public FinalizerContext finalizerCtx;
    public String mockId;
    public Boolean isFinalizer {
        get {
            return String.isNotBlank(parentCustomJobId);
        }
    }

    private GQueueableChain chain;

    public abstract void work();

    public void execute(QueueableContext ctx) {
        chain.execute(ctx);
    }

    public Integer compareTo(Object compareTo) {
        GQueueableJob compareToJob = (GQueueableJob) compareTo;
        if (isFinalizer && !compareToJob.isFinalizer) {
            return -1;
        }
        if (!isFinalizer && compareToJob.isFinalizer) {
            return 1;
        }
        if (priority != null && compareToJob.priority == null) {
            return -1;
        }
        if (priority == null && compareToJob.priority != null) {
            return 1;
        }
        if (priority == compareToJob.priority) {
            return 0;
        }
        return priority - compareToJob.priority;
    }

    public void enqueue(GQueueableChain chain) {
        this.chain = chain;
        if (delay != null) {
            salesforceJobId = System.enqueueJob(this, delay);
        } else if (asyncOptions != null) {
            salesforceJobId = System.enqueueJob(this, asyncOptions);
        } else {
            salesforceJobId = System.enqueueJob(this);
        }
    }

    public void setMainAttributes() {
        this.customJobId = UUID.randomUUID().toString();
        this.uniqueName = className + '::' + System.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ');
    }

    public void setChainCounterToName(Integer chainCounter) {
        this.uniqueName = this.uniqueName + '::' + String.valueOf(chainCounter);
    }

    public GQueueableJob cloneJob() {
        if (deepClone) {
            try {
                return cloneForDeepCopy();
            } catch (JSONException e) {
                throw new IllegalArgumentException(
                    'deepClone() failed for the job "' + className + '". ' +
                    'When using a namespaced package, override cloneForDeepCopy() in your GQueueableJob subclass: ' +
                    'public override GQueueableJob cloneForDeepCopy() { ' +
                    'return (GQueueableJob) JSON.deserialize(JSON.serialize(this), YourClassName.class); }'
                );
            }
        }
        return this.clone();
    }

    public virtual GQueueableJob cloneForDeepCopy() {
        String fullName = this.className;
        Type resolvedType = Type.forName(fullName);

        if (resolvedType == null && fullName.contains('.')) {
            resolvedType = Type.forName(
                fullName.substringBefore('.'),
                fullName.substringAfter('.')
            );
        }

        return (GQueueableJob) JSON.deserialize(JSON.serialize(this), resolvedType);
    }

    private String getFullClassName(Object job) {
        String result;
        try {
            DateTime typeCheck = (DateTime) job;
        } catch (System.TypeException expectedTypeException) {
            String message = expectedTypeException.getMessage()
                .substringAfter('Invalid conversion from runtime type ');
            result = message.substringBefore(' to Datetime');
        }
        return result;
    }

    public abstract class AllowsCallouts extends GQueueableJob implements Database.AllowsCallouts {
    }

    public abstract class Finalizer extends AllowsCallouts {
    }
}
