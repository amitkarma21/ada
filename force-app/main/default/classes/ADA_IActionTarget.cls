public interface ADA_IActionTarget {
  String targetName();
  ADA_ActionResult submit(String idempotencyKey, String payloadJson);
}
