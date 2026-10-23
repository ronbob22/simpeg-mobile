class ApiConstants {
  ApiConstants._();

  // Ganti ke URL Server Development
  static const String baseUrl = 'https://dev-cuti.pt-bengkulu.go.id';
  static const String apiBase = '$baseUrl/api';

  /// Token API tetap dari senior — wajib disertakan di header Authorization
  /// pada SETIAP request (terpisah dari token hasil login per-user).
  static const String staticApiToken =
      'di1Z5eP9N6yNfPYhjU9Op8Dg0JlrJ81jelQYiDErfdBWOe0FcQa8l86E2dFA';

  /// Nama device yang dikirim tiap login & dipakai lagi di header
  /// request-request setelahnya (device-name).
  static const String deviceName = 'SIMPEG Mobile';

  // Endpoints Auth & User Info
  static const String login = '$apiBase/auth-user-mob';
  static const String logout = '$apiBase/logout-mob';
  static const String userInfo = '$apiBase/get-user-info';
  static const String dashboard = '$apiBase/dashboard-mobile';

  // Endpoints Saldo
  static const String saldoCuti = '$apiBase/get-saldo-cuti';
  static const String searchSaldoNama = '$apiBase/search-saldo-nama';

  // Endpoints Pengajuan Cuti
  static const String infoCuti = '$apiBase/get-info-cuti';
  static const String saveTrxCuti = '$apiBase/save-trx-cuti';
  static const String cancelCuti = '$apiBase/cancel-cuti-mob';

  // Endpoints Verifikasi & Permohonan
  static String listPermohonanCuti(int tahapanId) =>
      '$apiBase/list-permohonan-cuti/$tahapanId';
  static String detilCuti(String tokenCuti) => '$apiBase/detil-cuti/$tokenCuti';
  static const String confirmCutiUp = '$apiBase/confirm-cuti-up-mobile';
  static const String confirmCutiAtasan = '$apiBase/confirm-cuti-atasan-mobile';
  static const String confirmCutiPejabat = '$apiBase/confirm-cuti-pejabat';
  static const String listAskCancel = '$apiBase/list-ask-cancel';
  static const String confirmCancelCuti = '$apiBase/confirm-cancel-cuti';

  // Endpoints History
  static String historyCutiPersonal(int page) =>
      '$apiBase/history-cuti-personal/$page';
  static String historyConfirmUp(int page) => '$apiBase/history-confirm-up/$page';
  static const String historyCutiAtasan = '$apiBase/history-cuti-atasan';
  static String historyCutiPejabat(int page) =>
      '$apiBase/history-cuti-pejabat/$page';
}