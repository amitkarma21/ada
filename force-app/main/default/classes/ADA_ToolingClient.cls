public with sharing class ADA_ToolingClient {
  public class ToolingException extends Exception {
  }

  @TestVisible
  private static final Integer MAX_PAGES = 25;
  private static final String CREDENTIAL = 'callout:ADA_Self_Tooling';
  private static final String QUERY_PATH = '/services/data/v68.0/tooling/query/?q=';
  private static final String DATA_QUERY_PATH = '/services/data/v68.0/query/?q=';
  private static final String DATA_API_PREFIX = '/services/data/';
  private static final String RECONNECT = 'Run the ADA setup to reconnect.';

  public List<Map<String, Object>> query(String soql) {
    return run(QUERY_PATH, soql);
  }

  // Some setup objects (DuplicateRule, FlowDefinitionView) exist only in the data API.
  public List<Map<String, Object>> queryData(String soql) {
    return run(DATA_QUERY_PATH, soql);
  }

  private static List<Map<String, Object>> run(String path, String soql) {
    if (String.isBlank(soql)) {
      throw new ToolingException('A Tooling API query is required.');
    }
    List<Map<String, Object>> records = new List<Map<String, Object>>();
    String endpoint = CREDENTIAL + path + EncodingUtil.urlEncode(soql, 'UTF-8');
    Integer pages = 0;
    while (endpoint != null) {
      pages++;
      if (pages > MAX_PAGES) {
        throw new ToolingException(
          'The Tooling API query returned too many pages.'
        );
      }
      Map<String, Object> body = fetch(endpoint);
      for (Object row : (List<Object>) body.get('records')) {
        records.add((Map<String, Object>) row);
      }
      endpoint = nextEndpoint(body);
    }
    return records;
  }

  private static String nextEndpoint(Map<String, Object> body) {
    if (body.get('done') == true) {
      return null;
    }
    Object next = body.get('nextRecordsUrl');
    if (!(next instanceof String)) {
      return null;
    }
    String path = (String) next;
    if (!path.startsWith(DATA_API_PREFIX)) {
      throw new ToolingException(
        'The Tooling API returned an unexpected next page address.'
      );
    }
    return CREDENTIAL + path;
  }

  private static Map<String, Object> fetch(String endpoint) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint(endpoint);
    request.setMethod('GET');
    request.setHeader('Accept', 'application/json');
    HttpResponse response;
    try {
      response = ADA_HttpGateway.execute(request);
    } catch (CalloutException e) {
      throw new ToolingException(
        'Could not reach the Tooling API. ' + RECONNECT
      );
    }
    Integer status = response.getStatusCode();
    if (status == 401 || status == 403) {
      throw new ToolingException(
        'The Tooling API refused the connection (' + status + '). ' + RECONNECT
      );
    }
    if (status == 400) {
      throw new ToolingException(
        'The Tooling API rejected the query (400)' + apiError(response)
      );
    }
    if (status < 200 || status > 299) {
      throw new ToolingException(
        'The Tooling API returned status ' + status + '.'
      );
    }
    return parse(response.getBody());
  }

  private static Map<String, Object> parse(String text) {
    try {
      Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
        text
      );
      if (!(body.get('records') instanceof List<Object>)) {
        throw new ToolingException(unreadable());
      }
      return body;
    } catch (JSONException e) {
      throw new ToolingException(unreadable());
    } catch (TypeException e) {
      throw new ToolingException(unreadable());
    }
  }

  private static String apiError(HttpResponse response) {
    try {
      List<Object> errors = (List<Object>) JSON.deserializeUntyped(
        response.getBody()
      );
      Map<String, Object> first = (Map<String, Object>) errors[0];
      return ': ' + first.get('errorCode') + ' ' + first.get('message');
    } catch (Exception e) {
      return '.';
    }
  }

  private static String unreadable() {
    return 'The Tooling API returned an unreadable response.';
  }
}
