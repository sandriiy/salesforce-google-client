public class GenAiGoogleOptions {
    public String cachedContent;
    public Integer thinkingBudget;
    public String thinkingLevel;
    public String mediaResolution;

    public GenAiGoogleOptions withCachedContent(String cachedContent) {
        this.cachedContent = cachedContent;
        return this;
    }

    public GenAiGoogleOptions withThinkingBudget(Integer thinkingBudget) {
        this.thinkingBudget = thinkingBudget;
        return this;
    }

    public GenAiGoogleOptions withThinkingLevel(String thinkingLevel) {
        this.thinkingLevel = thinkingLevel;
        return this;
    }

    public GenAiGoogleOptions withMediaResolution(String mediaResolution) {
        this.mediaResolution = mediaResolution;
        return this;
    }
}