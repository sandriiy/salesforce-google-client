public interface IGenAiResponseParser {
    GenAiResponse parse(HttpResponse response);
}