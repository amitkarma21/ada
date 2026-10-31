@IsTest
public class ADA_LlmTestSupport {
  public static final String VALID_CONTENT = '{"explanation":"The rule needs a future close date.","fixSteps":["Open the deal.","Set a future close date."],"suggestedAction":"NONE"}';

  public class Mock implements HttpCalloutMock {
    public Integer status = 200;
    public String body = envelope(VALID_CONTENT);
    public Boolean timeout = false;
    public Integer calls = 0;
    public List<HttpRequest> requests = new List<HttpRequest>();

    public HttpResponse respond(HttpRequest request) {
      calls++;
      requests.add(request);
      if (timeout) {
        throw new CalloutException('Read timed out');
      }
      HttpResponse response = new HttpResponse();
      response.setStatusCode(status);
      response.setBody(body);
      return response;
    }
  }

  public static Mock install() {
    Mock mock = new Mock();
    Test.setMock(HttpCalloutMock.class, mock);
    return mock;
  }

  public static String envelope(String content) {
    return JSON.serialize(
      new Map<String, Object>{
        'choices' => new List<Object>{
          new Map<String, Object>{
            'message' => new Map<String, Object>{
              'role' => 'assistant',
              'content' => content
            }
          }
        }
      }
    );
  }

  public static void useProvider(String provider, String model) {
    ADA_LlmProviderFactory.settingOverride = new ADA_Setting__mdt(
      LLM_Provider__c = provider,
      LLM_Model__c = model,
      LLM_Timeout_Ms__c = 5000
    );
  }

  public static void useOpenAi() {
    useProvider('OpenAICompatible', 'test-model');
  }

  public static ADA_Diagnosis diagnosis() {
    ADA_Diagnosis result = new ADA_Diagnosis(
      ADA_ErrorType.VALIDATION_RULE,
      0.98
    );
    result.objectApiName = 'Opportunity';
    result.componentType = 'ValidationRule';
    result.componentApiName = 'Close_Date_Rule';
    result.componentLabel = 'Close Date Rule';
    result.description = 'An open deal needs a future date.';
    return result;
  }

  public static ADA_PayloadBuilder.Extras extras() {
    ADA_PayloadBuilder.Extras extras = new ADA_PayloadBuilder.Extras();
    extras.objectLabel = 'Opportunity';
    extras.conditionFormulaMasked = 'AND(NOT(IsClosed), CloseDate < TODAY())';
    extras.fieldLabels = new List<String>{ 'Close Date' };
    extras.locale = 'en_AU';
    return extras;
  }

  public static ADA_Metadata_Index__c indexRow(Datetime modified) {
    return new ADA_Metadata_Index__c(
      Component_Type__c = 'ValidationRule',
      Object_Api_Name__c = 'Opportunity',
      Api_Name__c = 'Close_Date_Rule',
      Active__c = true,
      Source_Last_Modified__c = modified
    );
  }
}
