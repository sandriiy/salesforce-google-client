public class GenAiCandidate {
    public Integer index;
    public String finishReason;
    public Decimal avgLogprobs;
    public GenAiMessage content;
    public Map<String, Object> raw;

    public String text() {
        return content == null ? null : content.text();
    }
}