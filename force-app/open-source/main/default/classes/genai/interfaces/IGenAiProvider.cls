public interface IGenAiProvider {
    void validate(GenAiRequest request);
    GenAiInvocation build(GenAiRequest request);
    GenAiResponse parse(HttpResponse response);
}