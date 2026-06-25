// All Driver API v1 endpoint paths.
// Base URL is configured in ApiClient; only the path suffix lives here.
// Postman collection: MegaBoss API › Driver API v1 (Sanctum)
class Endpoints {
  Endpoints._();

  // ── Environments ────────────────────────────────────────────────────────────
  static const String staging = 'https://staging-v2.megaboss.store/public/api/v1';
  static const String local = 'http://127.0.0.1:8000/api/v1';

  // ── Auth ────────────────────────────────────────────────────────────────────
  static const String login = '/driver/login';
  static const String me = '/driver/me';
  static const String refresh = '/driver/refresh';
  static const String logout = '/driver/logout';

  // ── Device (FCM) ────────────────────────────────────────────────────────────
  static const String deviceRegister = '/driver/device/register';
  static const String device = '/driver/device';

  // ── Runsheets ───────────────────────────────────────────────────────────────
  static const String runsheetsActive = '/driver/runsheets/active';
  static const String runsheets = '/driver/runsheets';
  static String runsheet(int id) => '/driver/runsheets/$id';
  static String runsheetClose(int id) => '/driver/runsheets/$id/close';

  // ── Pickups ─────────────────────────────────────────────────────────────────
  static const String pickupsActive = '/driver/pickups/active';
  static String pickup(int id) => '/driver/pickups/$id';
  static String pickupAccept(int manifestId, int shipmentId) =>
      '/driver/pickups/$manifestId/shipments/$shipmentId/accept';
  static String pickupRefuse(int manifestId, int shipmentId) =>
      '/driver/pickups/$manifestId/shipments/$shipmentId/refuse';
  static String pickupClose(int id) => '/driver/pickups/$id/close';

  // ── Shipments ───────────────────────────────────────────────────────────────
  static String shipment(int id) => '/driver/shipments/$id';
  static String shipmentStatus(int id) => '/driver/shipments/$id/status';
  static String shipmentCalls(int id) => '/driver/shipments/$id/calls';

  // ── Scan ────────────────────────────────────────────────────────────────────
  static const String scanDelivery = '/driver/scan/delivery';
  static const String scanPickup = '/driver/scan/pickup';
  static const String scanBatch = '/driver/scan/batch';

  // ── Sync ────────────────────────────────────────────────────────────────────
  static const String syncPush = '/driver/sync';
  static const String syncPull = '/driver/sync/pull';

  // ── Calls ───────────────────────────────────────────────────────────────────
  static const String callsSync = '/driver/calls/sync';
  static const String callsStats = '/driver/calls/stats';

  // ── Notifications ───────────────────────────────────────────────────────────
  static const String notifications = '/driver/notifications';
  static const String notificationsUnreadCount =
      '/driver/notifications/unread-count';
  static String notificationRead(int id) => '/driver/notifications/$id/read';
  static const String notificationsReadAll = '/driver/notifications/read-all';

  // ── Stats ───────────────────────────────────────────────────────────────────
  static const String stats = '/driver/stats';

  // ── Motifs (return + refusal reasons) ───────────────────────────────────────
  static const String motifs = '/driver/motifs';
}
