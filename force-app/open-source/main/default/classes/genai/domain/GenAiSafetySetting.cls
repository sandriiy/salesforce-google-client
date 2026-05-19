public class GenAiSafetySetting {
    public String category;
    public String threshold;
    public String method;

    public GenAiSafetySetting(String category, String threshold, String method) {
        this.category = category;
        this.threshold = threshold;
        this.method = method;
    }
}