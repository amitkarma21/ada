@IsTest
public class ADA_AdoTestSupport {
  public static final String RULE = 'ADA_Sample_Close_Date';
  public static final String HTML_LINK = 'https://dev.azure.com/acme/_workitems/edit/42'; // ada-allow-url
  public static final String API_URL = 'https://dev.azure.com/acme/0b1c2d3e/_apis/wit/workItems/'; // ada-allow-url

  public class Mock implements HttpCalloutMock {
    public List<Integer> statuses = new List<Integer>();
    public List<String> bodies = new List<String>();
    public Boolean timeout = false;
    public List<HttpRequest> requests = new List<HttpRequest>();

    public Mock then(Integer status, String body) {
      statuses.add(status);
      bodies.add(body);
      return this;
    }

    public HttpResponse respond(HttpRequest request) {
      requests.add(request);
      if (timeout) {
        throw new CalloutException('Read timed out');
      }
      Integer index = requests.size() - 1;
      HttpResponse response = new HttpResponse();
      response.setStatusCode(index < statuses.size() ? statuses[index] : 500);
      response.setBody(index < bodies.size() ? bodies[index] : '{}');
      return response;
    }
  }

  public static Mock install() {
    Mock mock = new Mock();
    Test.setMock(HttpCalloutMock.class, mock);
    return mock;
  }

  public static String noHit() {
    return '{"workItems":[]}';
  }

  public static String hit(Integer id) {
    return '{"workItems":[{"id":' + id + ',"url":"' + API_URL + id + '"}]}';
  }

  public static String created(Integer id, String href) {
    return '{"id":' +
      id +
      ',"url":"' +
      API_URL +
      id +
      '","_links":{"html":{"href":"' +
      href +
      '"}}}';
  }

  public static ADA_Setting__mdt setting() {
    return new ADA_Setting__mdt(
      ADO_Enabled__c = true,
      ADO_Project__c = 'My Project',
      ADO_Area_Path__c = 'My Project\\ADA',
      ADO_Work_Item_Type__c = 'Bug'
    );
  }

  public static ADA_Diagnosis diagnosis() {
    ADA_Diagnosis result = ADA_LlmTestSupport.diagnosis();
    result.componentApiName = RULE;
    return result;
  }

  public static String payload(String notes) {
    return ADA_PayloadBuilder.toJson(
      ADA_PayloadBuilder.forWorkItem(diagnosis(), 'abc123', notes)
    );
  }
}
