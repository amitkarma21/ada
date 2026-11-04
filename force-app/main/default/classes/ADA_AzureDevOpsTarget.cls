public with sharing class ADA_AzureDevOpsTarget implements ADA_IActionTarget {
  public static final String NAME = 'AzureDevOps';
  private static final String BASE = 'callout:ADA_AzureDevOps/';
  private static final String API_VERSION = 'api-version=7.1';
  private static final String RULE_TAG = 'ADA-rule:';
  private static final Integer MAX_TITLE = 255;
  private static final Integer TIMEOUT_MS = 10000;
  private static final Pattern API_NAME = Pattern.compile('[A-Za-z0-9_]{1,80}');
  private static final Pattern WORK_ITEM_ID = Pattern.compile('[0-9]{1,12}');

  private final ADA_Setting__mdt setting;

  public ADA_AzureDevOpsTarget() {
    this(ADA_Setting__mdt.getInstance('Default'));
  }

  public ADA_AzureDevOpsTarget(ADA_Setting__mdt setting) {
    this.setting = setting;
  }

  public String targetName() {
    return NAME;
  }

  public ADA_ActionResult submit(String idempotencyKey, String payloadJson) {
    if (setting == null || setting.ADO_Enabled__c != true) {
      return fail(
        'Azure DevOps is not turned on. Ask your admin to set it up.'
      );
    }
    if (String.isBlank(setting.ADO_Project__c)) {
      return fail(
        'No Azure DevOps project is set. Ask your admin to set it up.'
      );
    }
    if (String.isBlank(idempotencyKey)) {
      return fail('This request has no idempotency key, so it was not sent.');
    }
    ADA_PayloadBuilder.WorkItemBody body = parse(payloadJson);
    if (body == null) {
      return fail('The work item was not valid, so nothing was sent.');
    }
    String rule = ruleOf(body.tags);
    if (rule == '') {
      return fail(
        'The work item names a rule ADA cannot search for, so nothing was sent.'
      );
    }
    try {
      if (rule != null) {
        ADA_ActionResult found = search(rule);
        if (found != null) {
          return found;
        }
      }
      return create(body);
    } catch (ADA_BlockedRequestException blocked) {
      return ADA_ActionResult.blocked(NAME, blocked.getMessage());
    } catch (ADA_GatewayException refused) {
      return fail(refused.getMessage());
    } catch (CalloutException unreachable) {
      return fail(
        'Azure DevOps did not answer in time. Try again in a minute.'
      );
    } catch (AdoException known) {
      return fail(known.getMessage());
    }
  }

  private ADA_ActionResult search(String rule) {
    String wiql =
      'SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project ' +
      'AND [System.Tags] CONTAINS \'' +
      RULE_TAG +
      rule +
      '\' AND [System.State] NOT IN (\'Closed\', \'Done\', \'Removed\') ' +
      'ORDER BY [System.Id] ASC';
    HttpResponse response = send(
      BASE + encode(setting.ADO_Project__c) + '/_apis/wit/wiql?' + API_VERSION,
      'application/json',
      JSON.serialize(new Map<String, String>{ 'query' => wiql })
    );
    Map<String, Object> parsed = checked(response);
    Object listed = parsed.get('workItems');
    if (
      !(listed instanceof List<Object>) || ((List<Object>) listed).isEmpty()
    ) {
      return null;
    }
    Object first = ((List<Object>) listed)[0];
    if (!(first instanceof Map<String, Object>)) {
      throw new AdoException('Azure DevOps sent a reply ADA could not read.');
    }
    Map<String, Object> item = (Map<String, Object>) first;
    String id = idOf(item.get('id'));
    ADA_ActionResult result = ADA_ActionResult.ok(
      NAME,
      'This problem is already tracked in Azure DevOps (work item ' +
        id +
        '), so ADA linked it instead of creating another.'
    );
    result.externalId = id;
    result.externalUrl = fromApiUrl(item.get('url'), id);
    return result;
  }

  private ADA_ActionResult create(ADA_PayloadBuilder.WorkItemBody body) {
    String type = String.isBlank(setting.ADO_Work_Item_Type__c)
      ? 'Bug'
      : setting.ADO_Work_Item_Type__c.trim();
    List<Map<String, Object>> patch = new List<Map<String, Object>>{
      add('System.Title', body.title.abbreviate(MAX_TITLE)),
      add('System.Description', html(body.description)),
      add('System.Tags', body.tags)
    };
    if (String.isNotBlank(setting.ADO_Area_Path__c)) {
      patch.add(add('System.AreaPath', setting.ADO_Area_Path__c.trim()));
    }
    HttpResponse response = send(
      BASE +
        encode(setting.ADO_Project__c) +
        '/_apis/wit/workitems/' +
        encode('$' + type) +
        '?' +
        API_VERSION,
      'application/json-patch+json',
      JSON.serialize(patch)
    );
    Map<String, Object> parsed = checked(response);
    String id = idOf(parsed.get('id'));
    ADA_ActionResult result = ADA_ActionResult.ok(
      NAME,
      'ADA created Azure DevOps work item ' + id + '.'
    );
    result.externalId = id;
    result.externalUrl = fromLinks(parsed.get('_links'));
    if (result.externalUrl == null) {
      result.externalUrl = fromApiUrl(parsed.get('url'), id);
    }
    return result;
  }

  private static HttpResponse send(
    String endpoint,
    String contentType,
    String body
  ) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint(endpoint);
    request.setMethod('POST');
    request.setHeader('Content-Type', contentType);
    request.setHeader('Accept', 'application/json');
    request.setTimeout(TIMEOUT_MS);
    request.setBody(body);
    return ADA_HttpGateway.execute(request);
  }

  private static Map<String, Object> checked(HttpResponse response) {
    Integer status = response.getStatusCode();
    if (status == 401 || status == 203) {
      throw new AdoException(
        'Azure DevOps rejected the sign-in (401). Ask your admin to renew the access token in the ADA_AzureDevOps credential.'
      );
    }
    if (status == 403) {
      throw new AdoException(
        'Azure DevOps says the token may not do this (403). Ask your admin to give it read and write access to work items.'
      );
    }
    if (status == 404) {
      throw new AdoException(
        'Azure DevOps could not find the project (404). Ask your admin to check the project name in the ADA settings.'
      );
    }
    if (status == 429) {
      throw new AdoException(
        'Azure DevOps is rate limiting requests (429). Try again in a minute.'
      );
    }
    if (status == 400) {
      throw new AdoException(
        'Azure DevOps rejected the work item (400). Ask your admin to check the area path and work item type in the ADA settings.'
      );
    }
    if (status < 200 || status > 299) {
      throw new AdoException('Azure DevOps returned status ' + status + '.');
    }
    Object parsed = null;
    try {
      parsed = JSON.deserializeUntyped(response.getBody());
    } catch (JSONException broken) {
      parsed = null;
    }
    if (parsed instanceof Map<String, Object>) {
      return (Map<String, Object>) parsed;
    }
    throw new AdoException('Azure DevOps sent a reply ADA could not read.');
  }

  private static ADA_PayloadBuilder.WorkItemBody parse(String payloadJson) {
    if (String.isBlank(payloadJson)) {
      return null;
    }
    try {
      ADA_PayloadBuilder.WorkItemBody body = (ADA_PayloadBuilder.WorkItemBody) JSON.deserialize(
        payloadJson,
        ADA_PayloadBuilder.WorkItemBody.class
      );
      if (
        body == null ||
        String.isBlank(body.title) ||
        String.isBlank(body.description) ||
        String.isBlank(body.tags)
      ) {
        return null;
      }
      return body;
    } catch (Exception broken) {
      return null;
    }
  }

  // null: no rule tag, so nothing to search for. '': a rule tag that is not an API name.
  private static String ruleOf(String tags) {
    for (String tag : tags.split(';')) {
      String trimmed = tag.trim();
      if (trimmed.startsWith(RULE_TAG)) {
        String rule = trimmed.substring(RULE_TAG.length());
        return API_NAME.matcher(rule).matches() ? rule : '';
      }
    }
    return null;
  }

  private static Map<String, Object> add(String field, String value) {
    return new Map<String, Object>{
      'op' => 'add',
      'path' => '/fields/' + field,
      'value' => value
    };
  }

  private static String html(String text) {
    return text.escapeHtml4().replace('\r\n', '\n').replace('\n', '<br>');
  }

  private static String encode(String value) {
    return EncodingUtil.urlEncode(value.trim(), 'UTF-8').replace('+', '%20');
  }

  private static String idOf(Object raw) {
    String id = raw == null ? '' : String.valueOf(raw);
    if (!WORK_ITEM_ID.matcher(id).matches()) {
      throw new AdoException('Azure DevOps sent a reply ADA could not read.');
    }
    return id;
  }

  private static String fromLinks(Object links) {
    if (!(links instanceof Map<String, Object>)) {
      return null;
    }
    Object html = ((Map<String, Object>) links).get('html');
    if (!(html instanceof Map<String, Object>)) {
      return null;
    }
    return secure(((Map<String, Object>) html).get('href'));
  }

  private static String fromApiUrl(Object apiUrl, String id) {
    String url = secure(apiUrl);
    if (url == null || !url.contains('/_apis/')) {
      return null;
    }
    return url.substringBefore('/_apis/') + '/_workitems/edit/' + id;
  }

  private static String secure(Object raw) {
    if (raw == null) {
      return null;
    }
    String url = String.valueOf(raw);
    return url.startsWith('https://') && !url.containsWhitespace() ? url : null; // ada-allow-url
  }

  private static ADA_ActionResult fail(String message) {
    return ADA_ActionResult.failed(NAME, message);
  }

  private class AdoException extends Exception {
  }
}
