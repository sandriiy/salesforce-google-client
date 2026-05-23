public inherited sharing class GQueueableChainFinalizer implements Finalizer {
    private GQueueableChain chain;

    public GQueueableChainFinalizer(GQueueableChain chain) {
        if (chain == null) {
            throw new IllegalArgumentException('GQueueableChain cannot be null');
        }
        this.chain = chain;
    }

    public void execute(FinalizerContext ctx) {
        chain.enqueueNextJobIfAnyFromFinalizer(ctx);
    }
}
