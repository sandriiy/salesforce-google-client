public inherited sharing class GQueueableSchedulable implements Schedulable {
    public GQueueableBuilder builder;

    public GQueueableSchedulable(GQueueableBuilder builder) {
        this.builder = builder;
    }

    public void execute(SchedulableContext scx) {
        builder.enqueue();
    }
}
