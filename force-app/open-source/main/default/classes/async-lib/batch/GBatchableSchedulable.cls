public class GBatchableSchedulable implements Schedulable {
    public GBatchableBuilder builder;

    public GBatchableSchedulable(GBatchableBuilder builder) {
        this.builder = builder;
    }

    public void execute(SchedulableContext scx) {
        builder.execute();
    }
}
