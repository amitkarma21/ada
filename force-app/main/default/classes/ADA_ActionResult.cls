public with sharing class ADA_ActionResult {
  public Boolean success { get; private set; }
  public String status { get; private set; }
  public String target { get; private set; }
  public String externalId { get; set; }
  public String externalUrl { get; set; }
  public String message { get; set; }

  private ADA_ActionResult(
    Boolean success,
    String status,
    String target,
    String message
  ) {
    this.success = success;
    this.status = status;
    this.target = target;
    this.message = message;
  }

  public static ADA_ActionResult ok(String target, String message) {
    return new ADA_ActionResult(true, 'Success', target, message);
  }

  public static ADA_ActionResult failed(String target, String message) {
    return new ADA_ActionResult(false, 'Failed', target, message);
  }

  public static ADA_ActionResult blocked(String target, String message) {
    return new ADA_ActionResult(false, 'Blocked', target, message);
  }
}
