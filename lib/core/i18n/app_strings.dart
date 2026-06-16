// Multi-language string lookup — FR default / AR (RTL) / EN.
// No code generation needed: switch on locale code.
// All string keys match the spec §6 (auth_*, login_*).
class AppStrings {
  const AppStrings._(this.locale);
  final String locale;

  static AppStrings of(String locale) => AppStrings._(locale);

  bool get isRtl => locale == 'ar';

  // ── Language selector chips ───────────────────────────────────────────────
  static const langFr = 'FR';
  static const langAr = 'AR';
  static const langEn = 'EN';

  // ── Login screen ──────────────────────────────────────────────────────────
  String get authTitle => switch (locale) {
        'ar' => 'تسجيل دخول السائق',
        'en' => 'Driver Login',
        _ => 'Connexion livreur',
      };

  String get authSubtitle => switch (locale) {
        'ar' => 'الوصول إلى جولاتك',
        'en' => 'Access your delivery routes',
        _ => 'Accédez à vos tournées',
      };

  String get authEmailLabel => switch (locale) {
        'ar' => 'البريد الإلكتروني',
        'en' => 'EMAIL',
        _ => 'EMAIL',
      };

  String get authEmailHint => switch (locale) {
        'ar' => 'مثال: prenom.nom@megaboss.ma',
        'en' => 'e.g. firstname.lastname@megaboss.ma',
        _ => 'ex. prenom.nom@megaboss.ma',
      };

  String get authEmailInvalid => switch (locale) {
        'ar' => 'عنوان البريد الإلكتروني غير صحيح',
        'en' => 'Invalid email address',
        _ => 'Adresse email invalide',
      };

  String get authPasswordLabel => switch (locale) {
        'ar' => 'كلمة المرور',
        'en' => 'PASSWORD',
        _ => 'MOT DE PASSE',
      };

  String get authPasswordRequired => switch (locale) {
        'ar' => 'كلمة المرور مطلوبة',
        'en' => 'Password is required',
        _ => 'Mot de passe requis',
      };

  String get authLogin => switch (locale) {
        'ar' => 'تسجيل الدخول',
        'en' => 'Sign in',
        _ => 'Se connecter',
      };

  String get authLoggingIn => switch (locale) {
        'ar' => 'جارٍ تسجيل الدخول…',
        'en' => 'Signing in…',
        _ => 'Connexion…',
      };

  String get authErrCredentials => switch (locale) {
        'ar' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
        'en' => 'Incorrect email or password.',
        _ => 'Email ou mot de passe incorrect.',
      };

  String get authErrNetwork => switch (locale) {
        'ar' => 'لا يوجد اتصال. تحقق من شبكتك وحاول مجدداً.',
        'en' => 'No connection. Check your network and try again.',
        _ => 'Pas de connexion. Vérifiez votre réseau et réessayez.',
      };

  String get authErrServer => switch (locale) {
        'ar' => 'خطأ في الخادم. حاول مجدداً بعد قليل.',
        'en' => 'Server error. Try again in a moment.',
        _ => 'Erreur serveur. Réessayez dans un instant.',
      };

  String get authSupport => switch (locale) {
        'ar' => 'نسيت كلمة المرور؟ تواصل مع الدعم',
        'en' => 'Forgot password? Contact support',
        _ => 'Mot de passe oublié ? Contacter le support',
      };

  String get showPassword => switch (locale) {
        'ar' => 'إظهار كلمة المرور',
        'en' => 'Show password',
        _ => 'Afficher le mot de passe',
      };

  String get hidePassword => switch (locale) {
        'ar' => 'إخفاء كلمة المرور',
        'en' => 'Hide password',
        _ => 'Masquer le mot de passe',
      };

  String authCooldown(int seconds) => switch (locale) {
        'ar' => 'إعادة المحاولة بعد $seconds ث',
        'en' => 'Retry in ${seconds}s',
        _ => 'Réessayer dans ${seconds}s',
      };

  String authFooter(String version) =>
      'MegaBoss · Livraison express · $version';

  // ── Dashboard — header ────────────────────────────────────────────────────
  String get dashHello => switch (locale) {
        'ar' => 'مرحباً,',
        'en' => 'Hello,',
        _ => 'Bonjour,',
      };

  String get dashStatusAvailable => switch (locale) {
        'ar' => 'متاح',
        'en' => 'Available',
        _ => 'Disponible',
      };

  String get dashStatusPause => switch (locale) {
        'ar' => 'في استراحة',
        'en' => 'On break',
        _ => 'En pause',
      };

  String get dashStatusUnavailable => switch (locale) {
        'ar' => 'غير متاح',
        'en' => 'Unavailable',
        _ => 'Indisponible',
      };

  String dashSyncPending(int n) => switch (locale) {
        'ar' => '$n عملية في انتظار المزامنة',
        'en' => '$n operation${n == 1 ? '' : 's'} pending sync',
        _ => '$n opération${n == 1 ? '' : 's'} en attente de synchro',
      };

  String get dashSyncUptodate => switch (locale) {
        'ar' => 'متزامن · محدّث',
        'en' => 'Synced · up to date',
        _ => 'Synchronisé · à jour',
      };

  // ── Dashboard — sections & cards ─────────────────────────────────────────
  String get dashSectionRunsheet => switch (locale) {
        'ar' => 'الجولة النشطة',
        'en' => 'ACTIVE RUNSHEET',
        _ => 'RUNSHEET ACTIF',
      };

  String get dashSectionPickup => switch (locale) {
        'ar' => 'الاستلام النشط',
        'en' => 'ACTIVE PICKUP',
        _ => 'PICKUP ACTIF',
      };

  String get dashSectionToday => switch (locale) {
        'ar' => 'اليوم',
        'en' => "TODAY",
        _ => "AUJOURD'HUI",
      };

  String get dashViewRunsheet => switch (locale) {
        'ar' => 'عرض الجولة',
        'en' => 'View runsheet',
        _ => 'Voir le runsheet',
      };

  String get dashViewManifest => switch (locale) {
        'ar' => 'عرض البيان',
        'en' => 'View manifest',
        _ => 'Voir le manifest',
      };

  String dashColis(int n) => switch (locale) {
        'ar' => '$n طرود',
        'en' => '$n parcel${n == 1 ? '' : 's'}',
        _ => '$n colis',
      };

  String get dashToCollect => switch (locale) {
        'ar' => 'طرود للجمع',
        'en' => 'parcels to collect',
        _ => 'colis à collecter',
      };

  String get dashRemaining => switch (locale) {
        'ar' => 'متبقية',
        'en' => 'Remaining',
        _ => 'Restants',
      };

  String get dashDelivered => switch (locale) {
        'ar' => 'تم التسليم',
        'en' => 'Delivered',
        _ => 'Livrés',
      };

  String get dashFailed => switch (locale) {
        'ar' => 'فشل',
        'en' => 'Failed',
        _ => 'Échecs',
      };

  String get dashDeliveries => switch (locale) {
        'ar' => 'التسليمات',
        'en' => 'Deliveries',
        _ => 'Livraisons',
      };

  String get dashCalls => switch (locale) {
        'ar' => 'المكالمات',
        'en' => 'Calls',
        _ => 'Appels',
      };

  String get dashCod => switch (locale) {
        'ar' => 'الدفع عند الاستلام · درهم',
        'en' => 'COD · MAD',
        _ => 'COD · DH',
      };

  String get dashScan => switch (locale) {
        'ar' => 'مسح',
        'en' => 'Scan',
        _ => 'Scanner',
      };

  // ── Dashboard — empty / error states ─────────────────────────────────────
  String get dashEmptyTitle => switch (locale) {
        'ar' => 'لا توجد جولة',
        'en' => 'No route today',
        _ => 'Aucune tournée',
      };

  String get dashEmptyBody => switch (locale) {
        'ar' => 'لم يتم تعيين أي جولة أو بيان استلام في الوقت الحالي.',
        'en' => 'No runsheet or manifest assigned at the moment.',
        _ => 'Aucun runsheet ni manifest assigné pour le moment.',
      };

  String get dashErrorTitle => switch (locale) {
        'ar' => 'تعذر تحميل لوحة القيادة.',
        'en' => 'Unable to load dashboard.',
        _ => 'Impossible de charger le tableau de bord.',
      };

  String get dashRetry => switch (locale) {
        'ar' => 'إعادة المحاولة',
        'en' => 'Retry',
        _ => 'Réessayer',
      };

  String get dashRefresh => switch (locale) {
        'ar' => 'تحديث',
        'en' => 'Refresh',
        _ => 'Actualiser',
      };

  // ── Dashboard — offline banner ────────────────────────────────────────────
  String get dashOfflineCache => switch (locale) {
        'ar' => 'بيانات مؤقتة',
        'en' => 'Cached data',
        _ => 'Données en cache',
      };

  String get dashOfflineToast => switch (locale) {
        'ar' => 'غير متصل — عرض البيانات المؤقتة',
        'en' => 'Offline — showing cached data',
        _ => 'Hors-ligne — affichage des données en cache',
      };

  // ── Tabs ──────────────────────────────────────────────────────────────────
  String get tabHome => switch (locale) {
        'ar' => 'الرئيسية',
        'en' => 'Home',
        _ => 'Accueil',
      };

  String get tabRunsheets => switch (locale) {
        'ar' => 'الجولات',
        'en' => 'Routes',
        _ => 'Runsht',
      };

  String get tabPickup => switch (locale) {
        'ar' => 'الاستلام',
        'en' => 'Pickup',
        _ => 'Pickup',
      };

  String get tabStats => switch (locale) {
        'ar' => 'إحصائيات',
        'en' => 'Stats',
        _ => 'Stats',
      };

  String get tabProfile => switch (locale) {
        'ar' => 'الملف',
        'en' => 'Profile',
        _ => 'Profil',
      };

  // ── Runsheets list ────────────────────────────────────────────────────────────
  String get rsTitle => switch (locale) {
        'ar' => 'الجولات',
        'en' => 'Runsheets',
        _ => 'Runsheets',
      };

  String get rsPeriodToday => switch (locale) {
        'ar' => 'اليوم',
        'en' => 'Today',
        _ => "Auj.",
      };

  String get rsPeriodWeek => switch (locale) {
        'ar' => 'الأسبوع',
        'en' => 'Week',
        _ => 'Semaine',
      };

  String get rsPeriodMonth => switch (locale) {
        'ar' => 'الشهر',
        'en' => 'Month',
        _ => 'Mois',
      };

  String get rsPeriodCustom => switch (locale) {
        'ar' => 'مخصص',
        'en' => 'Custom',
        _ => 'Perso',
      };

  String get rsStatusInProgress => switch (locale) {
        'ar' => 'قيد التنفيذ',
        'en' => 'In progress',
        _ => 'En cours',
      };

  String get rsStatusClosed => switch (locale) {
        'ar' => 'مغلق',
        'en' => 'Closed',
        _ => 'Clôturé',
      };

  String get rsStatusUpcoming => switch (locale) {
        'ar' => 'قادم',
        'en' => 'Upcoming',
        _ => 'À venir',
      };

  String get rsStatusCancelled => switch (locale) {
        'ar' => 'ملغى',
        'en' => 'Cancelled',
        _ => 'Annulé',
      };

  String rsLineSummary({
    required int total,
    required int delivered,
    required int failed,
    required int remaining,
  }) =>
      switch (locale) {
        'ar' =>
          '$total طرد · $delivered مسلّم · $failed فشل · $remaining متبقٍّ',
        'en' =>
          '$total parcel${total == 1 ? '' : 's'} · $delivered delivered · $failed failed · $remaining remaining',
        _ =>
          '$total colis · $delivered livrés · $failed échecs · $remaining restants',
      };

  String get rsCreate => switch (locale) {
        'ar' => 'إنشاء جولة',
        'en' => 'Create a runsheet',
        _ => 'Créer un runsheet',
      };

  String get rsEmptyTitle => switch (locale) {
        'ar' => 'لا توجد جولات',
        'en' => 'No runsheets',
        _ => 'Aucun runsheet',
      };

  String get rsEmptyBody => switch (locale) {
        'ar' => 'لا توجد جولات لهذه الفترة.',
        'en' => 'No routes for this period.',
        _ => 'Aucune tournée pour cette période.',
      };

  String get rsErrorTitle => switch (locale) {
        'ar' => 'تعذر تحميل الجولات.',
        'en' => 'Unable to load runsheets.',
        _ => 'Impossible de charger les runsheets.',
      };

  String get rsFilter => switch (locale) {
        'ar' => 'تصفية',
        'en' => 'Filter',
        _ => 'Filtrer',
      };

  // ── Runsheet detail ───────────────────────────────────────────────────────────
  String get rsdCodTotal => switch (locale) {
        'ar' => 'إجمالي الدفع عند الاستلام',
        'en' => 'COD total',
        _ => 'COD total',
      };

  String get rsdViewMap => switch (locale) {
        'ar' => 'عرض على الخريطة',
        'en' => 'View on map',
        _ => 'Voir sur la carte',
      };

  String get rsdClose => switch (locale) {
        'ar' => 'إغلاق',
        'en' => 'Close',
        _ => 'Clôturer',
      };

  String rsdColis(int n) => switch (locale) {
        'ar' => 'طرود · $n',
        'en' => 'PARCELS · $n',
        _ => 'COLIS · $n',
      };

  String get rsdCloseConfirmTitle => switch (locale) {
        'ar' => 'إغلاق الجولة؟',
        'en' => 'Close runsheet?',
        _ => 'Clôturer le runsheet ?',
      };

  String rsdCloseConfirmBody(int n) => switch (locale) {
        'ar' => 'لا يزال هناك $n طرد قيد الانتظار. هل تريد الإغلاق على أي حال؟',
        'en' =>
          'There ${n == 1 ? 'is' : 'are'} still $n parcel${n == 1 ? '' : 's'} pending. Close anyway?',
        _ =>
          'Il reste $n colis en attente. Clôturer quand même ?',
      };

  String get rsdCloseConfirmCancel => switch (locale) {
        'ar' => 'إلغاء',
        'en' => 'Cancel',
        _ => 'Annuler',
      };

  String get rsdCloseConfirmForce => switch (locale) {
        'ar' => 'إغلاق على أي حال',
        'en' => 'Close anyway',
        _ => 'Clôturer quand même',
      };

  String get rsdClosedToast => switch (locale) {
        'ar' => 'تم إغلاق الجولة',
        'en' => 'Runsheet closed',
        _ => 'Runsheet clôturé',
      };

  String get rsdEmpty => switch (locale) {
        'ar' => 'لا توجد طرود في هذه الجولة.',
        'en' => 'No parcels in this runsheet.',
        _ => 'Aucun colis dans ce runsheet.',
      };

  String get rsdError => switch (locale) {
        'ar' => 'تعذر تحميل الجولة.',
        'en' => 'Unable to load runsheet.',
        _ => 'Impossible de charger le runsheet.',
      };

  // Shipment statuses (used in detail + shipment rows)
  String get shipStatusDelivered => switch (locale) {
        'ar' => 'تم التسليم',
        'en' => 'Delivered',
        _ => 'Livré',
      };

  String get shipStatusFailed => switch (locale) {
        'ar' => 'فشل',
        'en' => 'Failed',
        _ => 'Échec',
      };

  String get shipStatusPending => switch (locale) {
        'ar' => 'قيد الانتظار',
        'en' => 'Pending',
        _ => 'En attente',
      };

  String get shipStatusReturned => switch (locale) {
        'ar' => 'مُعاد',
        'en' => 'Returned',
        _ => 'Retourné',
      };

  // ── Shipment detail (Colis) ───────────────────────────────────────────────
  String get colTitle => switch (locale) {
        'ar' => 'طرد',
        'en' => 'Parcel',
        _ => 'Colis',
      };

  String get colRecipient => switch (locale) {
        'ar' => 'المستلم',
        'en' => 'RECIPIENT',
        _ => 'DESTINATAIRE',
      };

  String get colPhone => switch (locale) {
        'ar' => 'الهاتف',
        'en' => 'PHONE',
        _ => 'TÉLÉPHONE',
      };

  String get colAddress => switch (locale) {
        'ar' => 'العنوان',
        'en' => 'ADDRESS',
        _ => 'ADRESSE',
      };

  String get colCodLabel => switch (locale) {
        'ar' => 'مبلغ الدفع عند الاستلام',
        'en' => 'COD AMOUNT',
        _ => 'MONTANT COD',
      };

  String get colCodSub => switch (locale) {
        'ar' => 'الدفع عند التسليم',
        'en' => 'Payment on delivery',
        _ => 'Paiement à la livraison',
      };

  String get colCallsLabel => switch (locale) {
        'ar' => 'المكالمات المرتبطة',
        'en' => 'LINKED CALLS',
        _ => 'APPELS LIÉS',
      };

  String get callNoAnswer => switch (locale) {
        'ar' => 'لم يرد',
        'en' => 'No answer',
        _ => 'Pas de réponse',
      };

  String get callJoined => switch (locale) {
        'ar' => 'تم التواصل',
        'en' => 'Reached · notified',
        _ => 'Joint · prévenu',
      };

  String get callUnreachable => switch (locale) {
        'ar' => 'غير متاح',
        'en' => 'Unreachable',
        _ => 'Non joignable',
      };

  String get colCall => switch (locale) {
        'ar' => 'اتصال',
        'en' => 'Call',
        _ => 'Appeler',
      };

  String get colNavigate => switch (locale) {
        'ar' => 'ملاحة',
        'en' => 'Navigate',
        _ => 'Naviguer',
      };

  String get colScanMark => switch (locale) {
        'ar' => 'مسح / تأكيد التسليم',
        'en' => 'Scan / Mark delivered',
        _ => 'Scanner / Marquer livré',
      };

  String get colError => switch (locale) {
        'ar' => 'تعذر تحميل الطرد.',
        'en' => 'Unable to load parcel.',
        _ => 'Impossible de charger le colis.',
      };

  String get colNoCalls => switch (locale) {
        'ar' => 'لا توجد مكالمات لهذا الطرد.',
        'en' => 'No calls for this parcel.',
        _ => 'Aucun appel pour ce colis.',
      };

  // ── Scan delivery screen ──────────────────────────────────────────────────
  String get scanModeDelivery => switch (locale) {
        'ar' => 'وضع التسليم',
        'en' => 'Delivery mode',
        _ => 'Mode Livraison',
      };

  String get scanConfirmRequired => switch (locale) {
        'ar' => 'تأكيد مطلوب',
        'en' => 'Confirmation required',
        _ => 'Confirmation requise',
      };

  String get scanAlignHint => switch (locale) {
        'ar' => 'ضع الباركود داخل الإطار',
        'en' => 'Align barcode in frame',
        _ => 'Alignez le code-barres dans le cadre',
      };

  String get scanOutOfRoute => switch (locale) {
        'ar' => 'طرد خارج الجولة',
        'en' => 'Out of route parcel',
        _ => 'Colis hors tournée',
      };

  String get scanDetected => switch (locale) {
        'ar' => 'تم الكشف',
        'en' => 'detected',
        _ => 'détecté',
      };

  String get scanCodLabel => switch (locale) {
        'ar' => 'المبلغ المستحق',
        'en' => 'COD TO COLLECT',
        _ => 'COD À PERCEVOIR',
      };

  String get scanDelivered => switch (locale) {
        'ar' => 'تم التسليم',
        'en' => 'Delivered',
        _ => 'Livré',
      };

  String get scanFailed => switch (locale) {
        'ar' => 'فشل',
        'en' => 'Failed',
        _ => 'Échec',
      };

  String get scanBack => switch (locale) {
        'ar' => 'رجوع',
        'en' => 'Back',
        _ => 'Retour',
      };

  String get scanToastDelivered => switch (locale) {
        'ar' => 'تم التسليم · المسح التالي…',
        'en' => 'Parcel delivered · next scan…',
        _ => 'Colis livré · scan suivant…',
      };

  String get scanToastQueued => switch (locale) {
        'ar' => 'محفوظ · في انتظار المزامنة',
        'en' => 'Saved · pending sync',
        _ => 'Enregistré · en attente de synchro',
      };

  String get scanPermTitle => switch (locale) {
        'ar' => 'اسمح للكاميرا بالمسح الضوئي',
        'en' => 'Allow camera to scan',
        _ => 'Autoriser la caméra pour scanner',
      };

  String get scanPermCta => switch (locale) {
        'ar' => 'فتح الإعدادات',
        'en' => 'Open settings',
        _ => 'Ouvrir les réglages',
      };

  String get scanReasonTitle => switch (locale) {
        'ar' => 'سبب الفشل',
        'en' => 'Failure reason',
        _ => "Raison de l'échec",
      };

  String get scanReasonAbsent => switch (locale) {
        'ar' => 'العميل غائب',
        'en' => 'Client absent',
        _ => 'Client absent',
      };

  String get scanReasonWrongAddress => switch (locale) {
        'ar' => 'عنوان غير صحيح',
        'en' => 'Incorrect address',
        _ => 'Adresse incorrecte',
      };

  String get scanReasonRefused => switch (locale) {
        'ar' => 'طرد مرفوض',
        'en' => 'Parcel refused',
        _ => 'Colis refusé',
      };

  String get scanReasonUnreachable => switch (locale) {
        'ar' => 'هاتف غير متاح',
        'en' => 'Phone unreachable',
        _ => 'Téléphone injoignable',
      };

  String get scanReasonRescheduled => switch (locale) {
        'ar' => 'تأجيل التوصيل',
        'en' => 'Delivery postponed',
        _ => 'Livraison reportée',
      };

  String get scanReasonComment => switch (locale) {
        'ar' => 'تعليق (اختياري)',
        'en' => 'COMMENT (OPTIONAL)',
        _ => 'COMMENTAIRE (OPTIONNEL)',
      };

  String get scanReasonCommentHint => switch (locale) {
        'ar' => 'رنّ مرتين — لا جواب، الجار غائب…',
        'en' => 'Rang 2x — no answer, neighbor absent…',
        _ => 'Sonné 2x — pas de réponse, voisin absent…',
      };

  String get scanConfirmFail => switch (locale) {
        'ar' => 'تأكيد الفشل',
        'en' => "Confirm failure",
        _ => "Confirmer l'échec",
      };

  String get scanFailTitle => switch (locale) {
        'ar' => 'فشل',
        'en' => 'Failure of',
        _ => 'Échec de',
      };

  String get scanConfirm => switch (locale) {
        'ar' => 'تأكيد',
        'en' => 'Confirm',
        _ => 'Confirmer',
      };

  String get scanConfirmTitle => switch (locale) {
        'ar' => 'التسليم',
        'en' => 'Delivery',
        _ => 'Livraison',
      };

  String get scanConfirmSubtitle => switch (locale) {
        'ar' => 'تأكيد الطرد',
        'en' => 'Confirm parcel',
        _ => 'Confirmer le colis',
      };

  String get scanConfirmDelivery => switch (locale) {
        'ar' => 'تأكيد التسليم',
        'en' => 'Confirm delivery',
        _ => 'Confirmer la livraison',
      };

  String get scanCodCollected => switch (locale) {
        'ar' => 'مبلغ الدفع المحصّل',
        'en' => 'COD COLLECTED',
        _ => 'MONTANT COD ENCAISSÉ',
      };

  String get scanCancel => switch (locale) {
        'ar' => 'إلغاء',
        'en' => 'Cancel',
        _ => 'Annuler',
      };

  String get scanOfflineBanner => switch (locale) {
        'ar' => 'غير متصل — الإجراءات مسجلة محلياً',
        'en' => 'Offline — actions saved locally',
        _ => 'Hors-ligne — actions enregistrées localement',
      };

  String get scanOfflineWarning => switch (locale) {
        'ar' =>
          'لا يوجد اتصال. سيتم تسجيل الإجراء ومزامنته تلقائياً عند عودة الشبكة.',
        'en' =>
          'No connection. The action will be saved and synced automatically when the network returns.',
        _ =>
          "Pas de connexion. L'action sera enregistrée et synchronisée automatiquement dès le retour du réseau.",
      };

  // ── Calls history screen ──────────────────────────────────────────────────
  String get callsTitle => switch (locale) {
        'ar' => 'سجل المكالمات',
        'en' => 'Call history',
        _ => 'Historique appels',
      };

  String get callsFilterAll => switch (locale) {
        'ar' => 'الكل',
        'en' => 'All',
        _ => 'Tous',
      };

  String get callsFilterJoined => switch (locale) {
        'ar' => 'متصل',
        'en' => 'Reached',
        _ => 'Joints',
      };

  String get callsFilterNoAnswer => switch (locale) {
        'ar' => 'لم يرد',
        'en' => 'No answer',
        _ => 'Sans rép.',
      };

  String get callsFilterUnreachable => switch (locale) {
        'ar' => 'غير متاح',
        'en' => 'Unreachable',
        _ => 'Non joign.',
      };

  String get callResultJoined => switch (locale) {
        'ar' => 'تم التواصل',
        'en' => 'Reached',
        _ => 'Joint',
      };

  String get callResultNoAnswer => switch (locale) {
        'ar' => 'لم يرد',
        'en' => 'No answer',
        _ => 'Pas de réponse',
      };

  String get callResultUnreachable => switch (locale) {
        'ar' => 'غير متاح',
        'en' => 'Unreachable',
        _ => 'Non joignable',
      };

  String get callsEmptyTitle => switch (locale) {
        'ar' => 'لا توجد مكالمات',
        'en' => 'No calls',
        _ => 'Aucun appel',
      };

  String callsEmptyBody(String filterLabel) => switch (locale) {
        'ar' => filterLabel.isEmpty
            ? 'لا توجد مكالمات لهذه الفترة.'
            : 'لا توجد مكالمات ($filterLabel) لهذه الفترة.',
        'en' => filterLabel.isEmpty
            ? 'No calls found for this period.'
            : 'No $filterLabel calls found for this period.',
        _ => filterLabel.isEmpty
            ? 'Aucun appel sur cette période.'
            : 'Aucun appel $filterLabel sur cette période.',
      };

  String get callsError => switch (locale) {
        'ar' => 'تعذر تحميل السجل.',
        'en' => 'Unable to load history.',
        _ => "Impossible de charger l'historique.",
      };

  String get callsRedial => switch (locale) {
        'ar' => 'إعادة الاتصال',
        'en' => 'Redial',
        _ => 'Rappeler',
      };

  String get callsOfflineCache => switch (locale) {
        'ar' => 'بيانات مؤقتة',
        'en' => 'Cached data',
        _ => 'Données en cache',
      };

  // ── Notifications screen ──────────────────────────────────────────────────
  String get notifTitle => switch (locale) {
        'ar' => 'الإشعارات',
        'en' => 'Notifications',
        _ => 'Notifications',
      };

  String get notifMarkAllRead => switch (locale) {
        'ar' => 'قراءة الكل',
        'en' => 'Mark all read',
        _ => 'Tout consulter',
      };

  String get notifEmptyTitle => switch (locale) {
        'ar' => 'لا توجد إشعارات',
        'en' => 'No notifications',
        _ => 'Aucune notification',
      };

  String get notifEmptyBody => switch (locale) {
        'ar' => 'ستُعلَم بالجولات والبيانات الجديدة.',
        'en' => 'You will be notified of new routes and manifests.',
        _ => 'Vous serez prévenu des nouvelles tournées et manifests.',
      };

  String get notifError => switch (locale) {
        'ar' => 'تعذر تحميل الإشعارات.',
        'en' => 'Unable to load notifications.',
        _ => 'Impossible de charger les notifications.',
      };

  String get notifOfflineCache => switch (locale) {
        'ar' => 'بيانات مؤقتة',
        'en' => 'Cached data',
        _ => 'Données en cache',
      };

  String get notifUnread => switch (locale) {
        'ar' => 'غير مقروء',
        'en' => 'unread',
        _ => 'non lu',
      };

  // Relative time helpers (fallback if no intl timeago package).
  String get notifTimeJustNow => switch (locale) {
        'ar' => 'الآن',
        'en' => 'just now',
        _ => "à l'instant",
      };

  String notifTimeMinutes(int n) => switch (locale) {
        'ar' => 'منذ $n د',
        'en' => '${n}min ago',
        _ => 'il y a $n min',
      };

  String notifTimeHours(int n) => switch (locale) {
        'ar' => 'منذ $n س',
        'en' => '${n}h ago',
        _ => 'il y a ${n}h',
      };

  String get notifTimeYesterday => switch (locale) {
        'ar' => 'أمس',
        'en' => 'Yesterday',
        _ => 'Hier',
      };

  String get notifGroupToday => switch (locale) {
        'ar' => 'اليوم',
        'en' => "Today",
        _ => "Aujourd'hui",
      };

  String get notifGroupYesterday => switch (locale) {
        'ar' => 'أمس',
        'en' => 'Yesterday',
        _ => 'Hier',
      };

  String get notifGroupOlder => switch (locale) {
        'ar' => 'سابقاً',
        'en' => 'Earlier',
        _ => 'Plus tôt',
      };

  // ── Settings screen ───────────────────────────────────────────────────────
  String get setTitle => switch (locale) {
        'ar' => 'الإعدادات',
        'en' => 'Settings',
        _ => 'Paramètres',
      };

  String setRole(String role, String city, String version) => switch (locale) {
        'ar' => '$role · $city · $version',
        'en' => '$role · $city · $version',
        _ => '$role · $city · $version',
      };

  String get setSectionPrefs => switch (locale) {
        'ar' => 'التفضيلات',
        'en' => 'PREFERENCES',
        _ => 'PRÉFÉRENCES',
      };

  String get setLang => switch (locale) {
        'ar' => 'اللغة',
        'en' => 'Language',
        _ => 'Langue',
      };

  String get setLangValueFr => 'Français';
  String get setLangValueAr => 'العربية';
  String get setLangValueEn => 'English';

  String get setTheme => switch (locale) {
        'ar' => 'المظهر',
        'en' => 'Theme',
        _ => 'Thème',
      };

  String get setThemeSub => switch (locale) {
        'ar' => 'فاتح / داكن / النظام',
        'en' => 'Light / Dark / System',
        _ => 'Clair / Sombre / Système',
      };

  String get setThemeLight => switch (locale) {
        'ar' => 'فاتح',
        'en' => 'Light',
        _ => 'Clair',
      };

  String get setThemeDark => switch (locale) {
        'ar' => 'داكن',
        'en' => 'Dark',
        _ => 'Sombre',
      };

  String get setThemeSystem => switch (locale) {
        'ar' => 'النظام',
        'en' => 'System',
        _ => 'Système',
      };

  String get setPush => switch (locale) {
        'ar' => 'إشعارات الدفع',
        'en' => 'Push notifications',
        _ => 'Notifications push',
      };

  String get setSectionSync => switch (locale) {
        'ar' => 'المزامنة',
        'en' => 'SYNCHRONIZATION',
        _ => 'SYNCHRONISATION',
      };

  String get setSyncState => switch (locale) {
        'ar' => 'حالة المزامنة',
        'en' => 'Sync status',
        _ => 'État de synchro',
      };

  String setSyncPending(int n, String time) => switch (locale) {
        'ar' => '$n عمليات في الانتظار · منذ $time',
        'en' => '$n pending · $time ago',
        _ => '$n opérations en attente · il y a $time',
      };

  String get setSyncUpToDate => switch (locale) {
        'ar' => 'محدث',
        'en' => 'Up to date',
        _ => 'À jour',
      };

  String get setForceSync => switch (locale) {
        'ar' => 'فرض المزامنة',
        'en' => 'Force sync',
        _ => 'Forcer la synchronisation',
      };

  String get setSyncing => switch (locale) {
        'ar' => 'جارٍ المزامنة…',
        'en' => 'Syncing…',
        _ => 'Synchronisation…',
      };

  String get setSyncOffline => switch (locale) {
        'ar' => 'غير متصل',
        'en' => 'Offline',
        _ => 'Hors-ligne',
      };

  String setSyncOfflinePending(int n) => switch (locale) {
        'ar' => 'غير متصل — $n في الانتظار',
        'en' => 'Offline — $n pending',
        _ => 'Hors-ligne — $n en attente',
      };

  String get setLogout => switch (locale) {
        'ar' => 'تسجيل الخروج',
        'en' => 'Sign out',
        _ => 'Se déconnecter',
      };

  String get setLogoutTitle => switch (locale) {
        'ar' => 'تسجيل الخروج؟',
        'en' => 'Sign out?',
        _ => 'Se déconnecter ?',
      };

  String get setLogoutCancel => switch (locale) {
        'ar' => 'إلغاء',
        'en' => 'Cancel',
        _ => 'Annuler',
      };

  String get setLogoutConfirm => switch (locale) {
        'ar' => 'تسجيل الخروج',
        'en' => 'Sign out',
        _ => 'Déconnexion',
      };

  String setLogoutUnsyncedWarn(int n) => switch (locale) {
        'ar' => '$n عمليات غير متزامنة ستُفقد.',
        'en' => '$n unsynced operation(s) will be lost.',
        _ => '$n opérations non synchronisées seront perdues.',
      };

  String get setSyncSuccessToast => switch (locale) {
        'ar' => 'تمت المزامنة بنجاح',
        'en' => 'Sync complete',
        _ => 'Synchronisation réussie',
      };

  String get setSyncErrorToast => switch (locale) {
        'ar' => 'فشلت المزامنة',
        'en' => 'Sync failed',
        _ => 'Échec de la synchronisation',
      };

  String get setLogoutError => switch (locale) {
        'ar' => 'فشل تسجيل الخروج. حاول مجدداً.',
        'en' => 'Sign out failed. Please try again.',
        _ => 'Erreur de déconnexion. Réessayez.',
      };

  // ── Pickups screen ─────────────────────────────────────────────────────────
  String get pickupTitle => switch (locale) {
        'ar' => 'الاستلام',
        'en' => 'Pickup',
        _ => 'Pickup',
      };

  String get pickupFilterAll => switch (locale) {
        'ar' => 'الكل',
        'en' => 'All',
        _ => 'Tous',
      };

  String get pickupStatusInProgress => switch (locale) {
        'ar' => 'جارٍ',
        'en' => 'In progress',
        _ => 'En cours',
      };

  String get pickupStatusUpcoming => switch (locale) {
        'ar' => 'قادم',
        'en' => 'Upcoming',
        _ => 'À venir',
      };

  String get pickupStatusDone => switch (locale) {
        'ar' => 'منتهٍ',
        'en' => 'Done',
        _ => 'Terminé',
      };

  String pickupSubToCollect(int n, String place) => switch (locale) {
        'ar' => '$n طرد للاستلام · $place',
        'en' => '$n parcel(s) to collect · $place',
        _ => '$n colis à collecter · $place',
      };

  String pickupSubDone(int total, int collected) => switch (locale) {
        'ar' => '$total طرد · $collected مُستلَم',
        'en' => '$total parcel(s) · $collected collected',
        _ => '$total colis · $collected collectés',
      };

  String get pickupEmptyTitle => switch (locale) {
        'ar' => 'لا توجد بيانات',
        'en' => 'No manifest',
        _ => 'Aucun manifest',
      };

  String pickupEmptyBody(String filter) => switch (locale) {
        'ar' => filter.isEmpty ? 'لا توجد بيانات استلام.' : 'لا توجد عمليات استلام لـ $filter.',
        'en' => filter.isEmpty ? 'No pickup manifest found.' : 'No pickups for $filter.',
        _ => filter.isEmpty ? 'Aucune collecte trouvée.' : 'Aucune collecte pour $filter.',
      };

  String get pickupError => switch (locale) {
        'ar' => 'تعذر تحميل بيانات الاستلام.',
        'en' => 'Unable to load pickups.',
        _ => 'Impossible de charger les pickups.',
      };

  // ── Pickup detail screen ────────────────────────────────────────────────────
  String get pkdCollect => switch (locale) {
        'ar' => 'استلام',
        'en' => 'Collect',
        _ => 'Collecter',
      };

  String get pkdRefuse => switch (locale) {
        'ar' => 'رفض',
        'en' => 'Refuse',
        _ => 'Refuser',
      };

  String pkdCollected(int n, int total) => switch (locale) {
        'ar' => '$n/$total مُستلَم',
        'en' => '$n/$total collected',
        _ => '$n/$total collectés',
      };

  String pkdShipments(int n) => switch (locale) {
        'ar' => 'الطرود ($n)',
        'en' => 'PARCELS ($n)',
        _ => 'COLIS ($n)',
      };

  String get pkdStatusPending => switch (locale) {
        'ar' => 'في الانتظار',
        'en' => 'Pending',
        _ => 'En attente',
      };

  String get pkdStatusCollected => switch (locale) {
        'ar' => 'مُستلَم',
        'en' => 'Collected',
        _ => 'Collecté',
      };

  String get pkdStatusRefused => switch (locale) {
        'ar' => 'مرفوض',
        'en' => 'Refused',
        _ => 'Refusé',
      };

  String get pkdRefuseTitle => switch (locale) {
        'ar' => 'تأكيد الرفض',
        'en' => 'Confirm refusal',
        _ => 'Confirmer le refus',
      };

  String get pkdRefuseConfirm => switch (locale) {
        'ar' => 'تأكيد',
        'en' => 'Confirm',
        _ => 'Confirmer',
      };

  String get pkdError => switch (locale) {
        'ar' => 'تعذر تحميل تفاصيل البيان.',
        'en' => 'Unable to load manifest.',
        _ => 'Impossible de charger le manifest.',
      };

  String pkdExpected(int total) => switch (locale) {
        'ar' => 'الطرود المتوقعة · $total',
        'en' => 'EXPECTED PARCELS · $total',
        _ => 'COLIS ATTENDUS · $total',
      };

  String pkdProgress(int n, int total) => switch (locale) {
        'ar' => '$n/$total مُستلَم',
        'en' => '$n/$total collected',
        _ => '$n/$total collectés',
      };

  String pkdCollectedAt(String time) => switch (locale) {
        'ar' => 'مُستلَم · $time',
        'en' => 'Collected · $time',
        _ => 'Collecté · $time',
      };

  String pkdRefusedReason(String reason) => switch (locale) {
        'ar' => 'مرفوض · $reason',
        'en' => 'Refused · $reason',
        _ => 'Refusé · $reason',
      };

  String get pkdScanRapide => switch (locale) {
        'ar' => 'مسح سريع',
        'en' => 'Quick scan',
        _ => 'Scan rapide',
      };

  String get pkdRefuseReasonTitle => switch (locale) {
        'ar' => 'سبب الرفض',
        'en' => 'Refuse reason',
        _ => 'Raison du refus',
      };

  String get pkdRefusePackaging => switch (locale) {
        'ar' => 'تعبئة',
        'en' => 'Packaging',
        _ => 'Emballage',
      };

  String get pkdRefuseMissing => switch (locale) {
        'ar' => 'مفقود',
        'en' => 'Missing',
        _ => 'Manquant',
      };

  String get pkdRefuseDamaged => switch (locale) {
        'ar' => 'تالف',
        'en' => 'Damaged',
        _ => 'Endommagé',
      };

  String get pkdRefuseOther => switch (locale) {
        'ar' => 'أخرى',
        'en' => 'Other',
        _ => 'Autre',
      };

  String get pkdManifestClose => switch (locale) {
        'ar' => 'إغلاق البيان',
        'en' => 'Close manifest',
        _ => 'Clôturer le manifest',
      };

  String get pkdAllCollected => switch (locale) {
        'ar' => 'جميع الطرود مُستلَمة',
        'en' => 'All parcels collected',
        _ => 'Tous les colis collectés',
      };

  String get pkdEmptyManifest => switch (locale) {
        'ar' => 'لا توجد طرود متوقعة في هذا البيان.',
        'en' => 'No parcels expected in this manifest.',
        _ => 'Aucun colis attendu dans ce manifest.',
      };

  String get pkdCall => switch (locale) {
        'ar' => 'اتصال بالمرسل',
        'en' => 'Call sender',
        _ => 'Appeler l\'expéditeur',
      };

  // ── Scan Pickup Rapide screen ─────────────────────────────────────────────

  String get qscanTitle => switch (locale) {
        'ar' => 'بيك آب سريع',
        'en' => 'Quick Pickup',
        _ => 'Pickup Rapide',
      };

  String get qscanModeSub => switch (locale) {
        'ar' => 'بدون تأكيد · متواصل',
        'en' => 'No confirmation · continuous',
        _ => 'Sans confirmation · continu',
      };

  String get qscanCounterLabel => switch (locale) {
        'ar' => 'طرود ممسوحة',
        'en' => 'parcels scanned',
        _ => 'colis scannés',
      };

  String qscanReview(int n) => switch (locale) {
        'ar' => '✓ طرود ممسوحة ($n)',
        'en' => '✓ parcels scanned ($n)',
        _ => '✓ colis scannés ($n)',
      };

  String qscanSend(int n) => switch (locale) {
        'ar' => 'إرسال ($n)',
        'en' => 'Send ($n)',
        _ => 'Envoyer ($n)',
      };

  String get qscanSending => switch (locale) {
        'ar' => 'جارٍ الإرسال…',
        'en' => 'Sending…',
        _ => 'Envoi…',
      };

  String qscanSentToast(int n) => switch (locale) {
        'ar' => '$n طرد تم استلامه',
        'en' => '$n parcel${n == 1 ? '' : 's'} collected',
        _ => '$n colis collectés',
      };

  String get qscanDuplicate => switch (locale) {
        'ar' => 'تم المسح مسبقاً',
        'en' => 'Already scanned',
        _ => 'Déjà scanné',
      };

  String get qscanOfflineBanner => switch (locale) {
        'ar' => 'غير متصل · الطرود تُحفظ تلقائياً',
        'en' => 'Offline · scans saved automatically',
        _ => 'Hors-ligne · scans sauvegardés',
      };

  String qscanSaveOffline(int n) => switch (locale) {
        'ar' => 'حفظ في الطابور ($n)',
        'en' => 'Queue ($n)',
        _ => 'Mettre en file ($n)',
      };

  String get qscanOfflineDeferred => switch (locale) {
        'ar' => 'غير متصل — إرسال مؤجل',
        'en' => 'Offline — send deferred',
        _ => 'Hors-ligne — envoi différé',
      };

  String get qscanQuitTitle => switch (locale) {
        'ar' => 'الخروج بدون إرسال؟',
        'en' => 'Quit without sending?',
        _ => 'Quitter sans envoyer ?',
      };

  String get qscanQuitBody => switch (locale) {
        'ar' => 'الطرود الممسوحة لن يتم إرسالها.',
        'en' => 'Scanned parcels will not be sent.',
        _ => 'Les colis scannés ne seront pas envoyés.',
      };

  String get qscanQuitStay => switch (locale) {
        'ar' => 'البقاء',
        'en' => 'Stay',
        _ => 'Rester',
      };

  String get qscanQuitLeave => switch (locale) {
        'ar' => 'خروج',
        'en' => 'Quit',
        _ => 'Quitter',
      };

  String get qscanSendError => switch (locale) {
        'ar' => 'خطأ أثناء الإرسال',
        'en' => 'Error sending batch',
        _ => 'Erreur lors de l\'envoi',
      };

  String get qscanReviewTitle => switch (locale) {
        'ar' => 'الطرود الممسوحة',
        'en' => 'Scanned parcels',
        _ => 'Colis scannés',
      };

  String get qscanReviewEmpty => switch (locale) {
        'ar' => 'لا توجد طرود ممسوحة',
        'en' => 'No parcels scanned',
        _ => 'Aucun colis scanné',
      };

  // ── Statistiques screen ───────────────────────────────────────────────────

  String get statsTitle => switch (locale) {
        'ar' => 'الإحصائيات',
        'en' => 'Statistics',
        _ => 'Statistiques',
      };

  String get statsPeriodToday => switch (locale) {
        'ar' => 'اليوم',
        'en' => 'Today',
        _ => 'Auj.',
      };

  String get statsPeriodWeek => switch (locale) {
        'ar' => 'الأسبوع',
        'en' => 'Week',
        _ => 'Semaine',
      };

  String get statsPeriodMonth => switch (locale) {
        'ar' => 'الشهر',
        'en' => 'Month',
        _ => 'Mois',
      };

  String get statsPeriodCustom => switch (locale) {
        'ar' => 'مخصص',
        'en' => 'Custom',
        _ => 'Perso',
      };

  String get statsKpiSuccess => switch (locale) {
        'ar' => 'توصيلات ناجحة',
        'en' => 'DELIVERIES',
        _ => 'LIVRAISONS RÉUSSIES',
      };

  String get statsKpiFailed => switch (locale) {
        'ar' => 'إخفاقات',
        'en' => 'FAILURES',
        _ => 'ÉCHECS',
      };

  String statsKpiCod(String currency) => switch (locale) {
        'ar' => 'COD المحصّل · $currency',
        'en' => 'COD COLLECTED · $currency',
        _ => 'COD COLLECTÉ · $currency',
      };

  String get statsKpiReachRate => switch (locale) {
        'ar' => 'معدل الوصول',
        'en' => 'REACHABILITY',
        _ => 'TAUX JOIGNABILITÉ',
      };

  String get statsChartTitle => switch (locale) {
        'ar' => 'توصيلات / يوم',
        'en' => 'DELIVERIES / DAY',
        _ => 'LIVRAISONS / JOUR',
      };

  String get statsTopFailTitle => switch (locale) {
        'ar' => 'أبرز أسباب الإخفاق',
        'en' => 'TOP FAILURE REASONS',
        _ => "TOP RAISONS D'ÉCHEC",
      };

  String get statsNoFailures => switch (locale) {
        'ar' => 'لا إخفاقات في هذه الفترة 🎉',
        'en' => 'No failures this period 🎉',
        _ => 'Aucun échec sur la période 🎉',
      };

  String get statsEmpty => switch (locale) {
        'ar' => 'لا توصيلات في هذه الفترة',
        'en' => 'No deliveries this period',
        _ => 'Aucune livraison sur la période',
      };

  String get statsError => switch (locale) {
        'ar' => 'تعذر تحميل الإحصائيات.',
        'en' => 'Unable to load statistics.',
        _ => 'Impossible de charger les statistiques.',
      };

  String get statsRetry => switch (locale) {
        'ar' => 'إعادة المحاولة',
        'en' => 'Retry',
        _ => 'Réessayer',
      };

  String get statsOfflineCache => switch (locale) {
        'ar' => 'بيانات مؤقتة · لا اتصال',
        'en' => 'Cached data · offline',
        _ => 'Données en cache · hors-ligne',
      };
}
