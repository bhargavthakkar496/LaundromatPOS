import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('th'),
    Locale('hi'),
  ];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  bool get _isArabic => locale.languageCode == 'ar';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'WashPOS',
      'language': 'Language',
      'english': 'English',
      'arabic': 'Arabic',
      'thai': 'Thai',
      'hindi': 'Hindi',
      'loginSubtitle': 'Flutter scaffold for the current Android demo flow.',
      'username': 'Username',
      'pin': 'PIN',
      'loginHint': 'Use your operator credentials.',
      'loginFailed':
          'Login failed. Check your credentials or backend connection.',
      'login': 'Login',
      'signingIn': 'Signing in...',
      'customerProfileHistory': 'Customer Profile & History',
      'orderHistory': 'Order History',
      'logout': 'Log Out',
      'storeManagerHome': 'Store Manager Home',
      'storeManagerHomeDescription':
          'Every major store control is available from this dashboard, with machines, customer handling, reporting, and day-end operations in one view.',
      'available': 'Available',
      'running': 'Running',
      'pickup': 'Pickup',
      'maintenance': 'Maintenance',
      'restockRequests': 'Restock Requests',
      'restockRequestsDescription':
          'Inventory-generated restock orders appear here for operator approval and remarks before purchasing picks them up.',
      'pendingApproval': 'Pending Approval',
      'requestedQty': 'Requested Qty',
      'supplier': 'Supplier',
      'branchLocation': 'Branch / Location',
      'requestedBy': 'Requested By',
      'created': 'Created',
      'requestNote': 'Request note',
      'approving': 'Approving...',
      'approveWithRemarks': 'Approve With Remarks',
      'inProcurement': 'In Procurement',
      'inProcurementDescription':
          'These inventory orders were approved on the operator screen and are now waiting to be marked as procured once stock arrives.',
      'operatorReady':
          'Store operator ready. Track machines, pickups, maintenance, and approvals from this dashboard.',
      'openCustomerScreenError': 'Could not open the customer screen window.',
      'openWhatsappError': 'Could not open WhatsApp for cycle completion.',
      'unassigned': 'Unassigned',
      'system': 'System',
      'machines': 'Machines',
      'inventory': 'Inventory',
      'customers': 'Customers',
      'payment': 'Payment',
      'orders': 'Orders',
      'staff': 'Staff',
      'pricing': 'Pricing',
      'screen': 'Screen',
      'reports': 'Reports',
      'revenue': 'Revenue',
      'refunds': 'Refunds',
      'checkout': 'Checkout',
      'customerLookup': 'Customer Lookup',
      'customerScreenTitle': 'Customer Screen',
      'operatorPayments': 'Operator Payments',
      'refundQueue': 'Refund Queue',
      'delivery': 'Delivery',
      'pickupDesk': 'Pickup Desk',
      'deliveryDesk': 'Delivery Desk',
      'deliveryDeskDescription':
          'Schedule driver handoff, push loads out for delivery, and confirm doorstep completion.',
      'pickupDeskDescription':
          'Clear completed machine loads quickly with reminders, callouts, and final pickup confirmation.',
      'scheduled': 'Scheduled',
      'outNow': 'Out Now',
      'readyLoads': 'Ready Loads',
      'statusFilters': 'Status Filters',
      'showingTasks': 'Showing {count} tasks',
      'noTasksForStatus': 'No delivery tasks match this status filter yet.',
      'deliveryTasksEmptyTitle': 'No delivery tasks yet',
      'deliveryTasksEmptyMessage':
          'Recent paid orders will appear here so the team can schedule and complete deliveries.',
      'pickupTasksEmptyTitle': 'No pickup jobs waiting',
      'pickupTasksEmptyMessage':
          'When a cycle finishes and the machine moves to pickup-ready, it will appear here.',
      'phone': 'Phone',
      'ref': 'Ref',
      'amount': 'Amount',
      'machine': 'Machine',
      'window': 'Window',
      'driver': 'Driver',
      'callCustomer': 'Call Customer',
      'sendReminder': 'Send Reminder',
      'markPickedUp': 'Mark Picked Up',
      'pickupReady': 'Ready For Pickup',
      'reminderSent': 'Reminder Sent',
      'pickedUpStatus': 'Picked Up',
      'pickupUpdatedFor': 'Pickup updated for',
      'cancel': 'Cancel',
      'deliveryUpdateSent': 'Delivery update opened for',
      'pickupReminderSent': 'Pickup reminder opened for',
      'markedPickedUp': 'marked picked up.',
      'scheduleDelivery': 'Schedule Delivery',
      'saveDelivery': 'Save Delivery',
      'assignedDriver': 'Assigned driver',
      'deliveryWindow': 'Delivery window',
      'editDelivery': 'Edit Delivery',
      'cancelDelivery': 'Cancel Delivery',
      'reopenDelivery': 'Reopen Delivery',
      'sendUpdate': 'Send Update',
      'markOutForDelivery': 'Mark Out For Delivery',
      'markDelivered': 'Mark Delivered',
      'pendingSchedule': 'Pending Schedule',
      'outForDelivery': 'Out For Delivery',
      'delivered': 'Delivered',
      'cancelled': 'Cancelled',
      'deliveryUpdatedFor': 'Delivery updated for',
      'deliveryCustomerContact': 'Delivery customer',
      'pickupCustomerContact': 'Pickup customer',
      'saving': 'Saving...',
      'updating': 'Updating...',
      'todayDeliveryWindow': 'Today, 4 PM - 7 PM',
      'managerOptions': 'Hello Store Manager',
      'managerOptionsDescription': 'What would you like to do today?',
      'machineOverview': 'Machine Overview',
      'inventoryDashboard': 'Inventory Dashboard',
      'inventoryDashboardDescription':
          'Track stock risk, pending replenishment, and item movement from one screen, then narrow into the exact items that need action.',
      'categories': 'Categories',
      'visibleItems': 'Visible Items',
      'selected': 'Selected',
      'all': 'All',
      'lowStock': 'Low Stock',
      'outOfStock': 'Out Of Stock',
      'stockValue': 'Stock Value',
      'pendingPos': 'Pending POs',
      'expiringSoon': 'Expiring Soon',
      'categoryOptions': 'Category Options',
      'categoryOptionsDescription':
          'Keep the compact category shortcuts, but use them as a filter over the full inventory dataset.',
      'searchFilterSort': 'Search, Filter, And Sort',
      'searchByItemOrSku': 'Search by item name or SKU',
      'stockStatus': 'Stock status',
      'healthy': 'Healthy',
      'low': 'Low',
      'sortBy': 'Sort by',
      'sortOrder': 'Sort order',
      'reorderUrgency': 'Reorder urgency',
      'quantity': 'Quantity',
      'lastRestocked': 'Last restocked',
      'descending': 'Descending',
      'ascending': 'Ascending',
      'reset': 'Reset',
      'allInventoryItems': 'All Inventory Items',
      'inventoryItemsSuffix': 'Items',
      'noInventoryItemsMatch':
          'No inventory items match the current search and filters.',
      'noExpiry': 'No expiry',
      'awaitingApproval': 'Awaiting approval',
      'restockApproved':
          'Order checkout is approved and the item is now in procurement.',
      'restockOrder': 'Restock Order',
      'approvedQuantity': 'Approved Quantity',
      'approvedOn': 'Approved On',
      'operatorRemarks': 'Operator remarks',
      'restockPendingApproval':
          'Restock request has been sent to the operator screen and is awaiting approval.',
      'creatingRestockRequest': 'Creating Restock Request...',
      'orderRestock': 'Order / Restock',
      'hideMovementHistory': 'Hide Movement History',
      'showMovementHistory': 'Show Movement History',
      'stockMovementHistory': 'Stock Movement History',
      'stockMovementHistoryDescription':
          'Ledger entries help explain exactly how the current balance was reached.',
      'noMovementHistory': 'No movement history recorded yet for this item.',
      'delta': 'Delta',
      'balance': 'Balance',
      'when': 'When',
      'reference': 'Reference',
      'manualEntry': 'Manual entry',
      'by': 'By',
      'received': 'Received',
      'consumed': 'Consumed',
      'transferred': 'Transferred',
      'damaged': 'Damaged',
      'returned': 'Returned',
      'manualCorrection': 'Manual Correction',
      'barcode': 'Barcode',
      'packSize': 'Pack Size',
      'unitType': 'Unit Type',
      'parLevel': 'Par Level',
      'sellingPrice': 'Selling Price',
      'recordStatus': 'Record Status',
      'active': 'Active',
      'inactive': 'Inactive',
      'notAssigned': 'Not assigned',
      'notSet': 'Not set',
      'notApplicable': 'Not applicable',
      'urgency': 'Urgency',
      'branchLocationShort': 'Branch / Location',
      'detergent': 'Detergent',
      'disinfectant': 'Disinfectant',
      'liquid': 'Liquid',
      'soap': 'Soap',
      'softener': 'Softener',
    },
    'ar': {
      'appTitle': 'واش بوس',
      'language': 'اللغة',
      'english': 'الإنجليزية',
      'arabic': 'العربية',
      'thai': 'التايلاندية',
      'hindi': 'الهندية',
      'loginSubtitle': 'واجهة Flutter تجريبية لتدفق أندرويد الحالي.',
      'username': 'اسم المستخدم',
      'pin': 'الرقم السري',
      'loginHint': 'استخدم بيانات دخول المشغل.',
      'loginFailed':
          'فشل تسجيل الدخول. تحقق من بيانات الاعتماد أو اتصال الخادم.',
      'login': 'تسجيل الدخول',
      'signingIn': 'جارٍ تسجيل الدخول...',
      'customerProfileHistory': 'ملف العميل والسجل',
      'orderHistory': 'سجل الطلبات',
      'logout': 'تسجيل الخروج',
      'storeManagerHome': 'الصفحة الرئيسية لمدير المتجر',
      'storeManagerHomeDescription':
          'جميع عناصر التحكم الرئيسية في المتجر متاحة من هذه اللوحة، بما يشمل الماكينات والعملاء والتقارير وعمليات نهاية اليوم.',
      'available': 'متاح',
      'running': 'قيد التشغيل',
      'pickup': 'جاهز للاستلام',
      'maintenance': 'صيانة',
      'restockRequests': 'طلبات إعادة التخزين',
      'restockRequestsDescription':
          'تظهر هنا طلبات إعادة التخزين الصادرة من المخزون لاعتماد المشغل وإضافة الملاحظات قبل أن يتابعها قسم المشتريات.',
      'pendingApproval': 'بانتظار الاعتماد',
      'requestedQty': 'الكمية المطلوبة',
      'supplier': 'المورد',
      'branchLocation': 'الفرع / الموقع',
      'requestedBy': 'طُلب بواسطة',
      'created': 'تاريخ الإنشاء',
      'requestNote': 'ملاحظة الطلب',
      'approving': 'جارٍ الاعتماد...',
      'approveWithRemarks': 'اعتماد مع ملاحظات',
      'inProcurement': 'قيد التوريد',
      'inProcurementDescription':
          'تم اعتماد طلبات المخزون هذه على شاشة المشغل وهي الآن بانتظار تأكيد التوريد عند وصول المخزون.',
      'operatorReady':
          'المشغل جاهز. تابع الماكينات وعمليات الاستلام والصيانة والموافقات من هذه اللوحة.',
      'openCustomerScreenError': 'تعذر فتح نافذة شاشة العميل.',
      'openWhatsappError': 'تعذر فتح واتساب لإشعار اكتمال الدورة.',
      'unassigned': 'غير محدد',
      'system': 'النظام',
      'machines': 'الماكينات',
      'inventory': 'المخزون',
      'customers': 'العملاء',
      'payment': 'الدفع',
      'orders': 'الطلبات',
      'staff': 'الموظفون',
      'pricing': 'الأسعار',
      'screen': 'الشاشة',
      'reports': 'التقارير',
      'revenue': 'الإيراد',
      'refunds': 'الاستردادات',
      'checkout': 'الدفع النهائي',
      'customerLookup': 'بحث العملاء',
      'customerScreenTitle': 'شاشة العميل',
      'operatorPayments': 'مدفوعات المشغل',
      'refundQueue': 'قائمة الاسترداد',
      'delivery': 'التوصيل',
      'pickupDesk': 'مكتب الاستلام',
      'deliveryDesk': 'مكتب التوصيل',
      'deliveryDeskDescription':
          'جدول تسليم السائقين، وأرسل الطلبات للتوصيل، ثم أكد التسليم عند الباب.',
      'pickupDeskDescription':
          'أنهِ الطلبات الجاهزة للاستلام بسرعة من خلال التذكير والاتصال وتأكيد التسليم النهائي.',
      'scheduled': 'مجدول',
      'outNow': 'خارج للتوصيل',
      'readyLoads': 'طلبات جاهزة',
      'statusFilters': 'عوامل تصفية الحالة',
      'showingTasks': 'يتم عرض {count} مهام',
      'noTasksForStatus':
          'لا توجد مهام توصيل تطابق عامل تصفية الحالة هذا حتى الآن.',
      'deliveryTasksEmptyTitle': 'لا توجد مهام توصيل بعد',
      'deliveryTasksEmptyMessage':
          'ستظهر هنا الطلبات المدفوعة الأخيرة ليتمكن الفريق من جدولتها وإكمال توصيلها.',
      'pickupTasksEmptyTitle': 'لا توجد طلبات استلام حالياً',
      'pickupTasksEmptyMessage':
          'عندما تنتهي الدورة وتصبح الماكينة جاهزة للاستلام ستظهر هنا.',
      'phone': 'الهاتف',
      'ref': 'المرجع',
      'amount': 'المبلغ',
      'machine': 'الماكينة',
      'window': 'الفترة',
      'driver': 'السائق',
      'callCustomer': 'اتصل بالعميل',
      'sendReminder': 'إرسال تذكير',
      'markPickedUp': 'تأكيد الاستلام',
      'pickupReady': 'جاهز للاستلام',
      'reminderSent': 'تم إرسال تذكير',
      'pickedUpStatus': 'تم الاستلام',
      'pickupUpdatedFor': 'تم تحديث الاستلام للعميل',
      'cancel': 'إلغاء',
      'deliveryUpdateSent': 'تم فتح تحديث التوصيل للعميل',
      'pickupReminderSent': 'تم فتح تذكير الاستلام للعميل',
      'markedPickedUp': 'تم تأكيد استلامه.',
      'scheduleDelivery': 'جدولة التوصيل',
      'saveDelivery': 'حفظ التوصيل',
      'assignedDriver': 'السائق المعيّن',
      'deliveryWindow': 'فترة التوصيل',
      'editDelivery': 'تعديل التوصيل',
      'cancelDelivery': 'إلغاء التوصيل',
      'reopenDelivery': 'إعادة فتح التوصيل',
      'sendUpdate': 'إرسال تحديث',
      'markOutForDelivery': 'تحديد كخارج للتوصيل',
      'markDelivered': 'تحديد كتم التسليم',
      'pendingSchedule': 'بانتظار الجدولة',
      'outForDelivery': 'خارج للتوصيل',
      'delivered': 'تم التسليم',
      'cancelled': 'ملغي',
      'deliveryUpdatedFor': 'تم تحديث التوصيل للعميل',
      'deliveryCustomerContact': 'عميل التوصيل',
      'pickupCustomerContact': 'عميل الاستلام',
      'saving': 'جارٍ الحفظ...',
      'updating': 'جارٍ التحديث...',
      'todayDeliveryWindow': 'اليوم، 4 م - 7 م',
      'managerOptions': 'مرحباً مدير المتجر',
      'managerOptionsDescription': 'ماذا تود أن تفعل اليوم؟',
      'machineOverview': 'نظرة عامة على الماكينات',
    },
    'th': {
      'appTitle': 'วอชพอส',
      'language': 'ภาษา',
      'english': 'อังกฤษ',
      'arabic': 'อาหรับ',
      'thai': 'ไทย',
      'hindi': 'ฮินดี',
      'loginSubtitle': 'โครงร่าง Flutter สำหรับเดโม Android ปัจจุบัน',
      'username': 'ชื่อผู้ใช้',
      'pin': 'รหัส PIN',
      'loginHint': 'ใช้ข้อมูลเข้าสู่ระบบของผู้ปฏิบัติงาน',
      'loginFailed':
          'เข้าสู่ระบบไม่สำเร็จ โปรดตรวจสอบข้อมูลเข้าสู่ระบบหรือการเชื่อมต่อแบ็กเอนด์',
      'login': 'เข้าสู่ระบบ',
      'signingIn': 'กำลังเข้าสู่ระบบ...',
      'customerProfileHistory': 'โปรไฟล์ลูกค้าและประวัติ',
      'orderHistory': 'ประวัติคำสั่งซื้อ',
      'logout': 'ออกจากระบบ',
      'storeManagerHome': 'หน้าหลักผู้จัดการสาขา',
      'storeManagerHomeDescription':
          'การควบคุมหลักของร้านทั้งหมดพร้อมใช้งานจากแดชบอร์ดนี้ ครอบคลุมเครื่อง ลูกค้า รายงาน และงานสิ้นวันในหน้าจอเดียว',
      'available': 'ว่าง',
      'running': 'กำลังทำงาน',
      'pickup': 'รอรับ',
      'maintenance': 'ซ่อมบำรุง',
      'restockRequests': 'คำขอเติมสต็อก',
      'restockRequestsDescription':
          'คำขอเติมสต็อกจากระบบสินค้าคงคลังจะแสดงที่นี่เพื่อให้ผู้ปฏิบัติงานอนุมัติและใส่หมายเหตุก่อนจัดซื้อดำเนินการต่อ',
      'pendingApproval': 'รออนุมัติ',
      'requestedQty': 'จำนวนที่ขอ',
      'supplier': 'ซัพพลายเออร์',
      'branchLocation': 'สาขา / ตำแหน่ง',
      'requestedBy': 'ผู้ร้องขอ',
      'created': 'สร้างเมื่อ',
      'requestNote': 'หมายเหตุคำขอ',
      'approving': 'กำลังอนุมัติ...',
      'approveWithRemarks': 'อนุมัติพร้อมหมายเหตุ',
      'inProcurement': 'อยู่ระหว่างจัดซื้อ',
      'inProcurementDescription':
          'คำขอสินค้าคงคลังเหล่านี้ได้รับการอนุมัติจากหน้าจอผู้ปฏิบัติงานแล้ว และกำลังรอการยืนยันว่าจัดซื้อสำเร็จเมื่อสต็อกมาถึง',
      'operatorReady':
          'ผู้ปฏิบัติงานพร้อมแล้ว ติดตามเครื่อง การรับผ้า งานซ่อมบำรุง และการอนุมัติได้จากแดชบอร์ดนี้',
      'openCustomerScreenError': 'ไม่สามารถเปิดหน้าต่างหน้าจอลูกค้าได้',
      'openWhatsappError': 'ไม่สามารถเปิด WhatsApp เพื่อแจ้งการจบรอบการซักได้',
      'unassigned': 'ยังไม่กำหนด',
      'system': 'ระบบ',
      'machines': 'เครื่อง',
      'inventory': 'สินค้าคงคลัง',
      'customers': 'ลูกค้า',
      'payment': 'การชำระเงิน',
      'orders': 'คำสั่งซื้อ',
      'staff': 'พนักงาน',
      'pricing': 'ราคา',
      'screen': 'หน้าจอ',
      'reports': 'รายงาน',
      'revenue': 'รายได้',
      'refunds': 'คืนเงิน',
      'checkout': 'ชำระเงิน',
      'customerLookup': 'ค้นหาลูกค้า',
      'customerScreenTitle': 'หน้าจอลูกค้า',
      'operatorPayments': 'การชำระเงินของผู้ปฏิบัติงาน',
      'refundQueue': 'คิวคืนเงิน',
      'delivery': 'จัดส่ง',
      'pickupDesk': 'จุดรับผ้า',
      'deliveryDesk': 'จุดจัดส่ง',
      'deliveryDeskDescription':
          'จัดตารางคนขับ ส่งงานออกจัดส่ง และยืนยันการส่งถึงหน้าประตู',
      'pickupDeskDescription':
          'จัดการงานที่พร้อมรับอย่างรวดเร็วด้วยการเตือน การโทร และการยืนยันรับผ้า',
      'scheduled': 'จัดตารางแล้ว',
      'outNow': 'กำลังจัดส่ง',
      'readyLoads': 'งานพร้อมรับ',
      'statusFilters': 'ตัวกรองสถานะ',
      'showingTasks': 'กำลังแสดง {count} งาน',
      'noTasksForStatus': 'ยังไม่มีงานจัดส่งที่ตรงกับตัวกรองสถานะนี้',
      'deliveryTasksEmptyTitle': 'ยังไม่มีงานจัดส่ง',
      'deliveryTasksEmptyMessage':
          'คำสั่งซื้อที่ชำระเงินล่าสุดจะแสดงที่นี่เพื่อให้ทีมจัดตารางและดำเนินการจัดส่ง',
      'pickupTasksEmptyTitle': 'ไม่มีงานรับผ้ารออยู่',
      'pickupTasksEmptyMessage':
          'เมื่อรอบการซักเสร็จและเครื่องพร้อมรับ งานจะปรากฏที่นี่',
      'phone': 'โทรศัพท์',
      'ref': 'อ้างอิง',
      'amount': 'จำนวนเงิน',
      'machine': 'เครื่อง',
      'window': 'ช่วงเวลา',
      'driver': 'คนขับ',
      'callCustomer': 'โทรหาลูกค้า',
      'sendReminder': 'ส่งการเตือน',
      'markPickedUp': 'ยืนยันรับแล้ว',
      'pickupReady': 'พร้อมรับผ้า',
      'reminderSent': 'ส่งการเตือนแล้ว',
      'pickedUpStatus': 'รับผ้าแล้ว',
      'pickupUpdatedFor': 'อัปเดตงานรับผ้าสำหรับ',
      'cancel': 'ยกเลิก',
      'deliveryUpdateSent': 'เปิดอัปเดตการจัดส่งให้',
      'pickupReminderSent': 'เปิดการเตือนรับผ้าให้',
      'markedPickedUp': 'ถูกทำเครื่องหมายว่ารับแล้ว',
      'scheduleDelivery': 'จัดตารางจัดส่ง',
      'saveDelivery': 'บันทึกการจัดส่ง',
      'assignedDriver': 'คนขับที่รับผิดชอบ',
      'deliveryWindow': 'ช่วงเวลาจัดส่ง',
      'editDelivery': 'แก้ไขการจัดส่ง',
      'cancelDelivery': 'ยกเลิกการจัดส่ง',
      'reopenDelivery': 'เปิดงานจัดส่งอีกครั้ง',
      'sendUpdate': 'ส่งอัปเดต',
      'markOutForDelivery': 'ทำเครื่องหมายว่ากำลังจัดส่ง',
      'markDelivered': 'ทำเครื่องหมายว่าส่งแล้ว',
      'pendingSchedule': 'รอจัดตาราง',
      'outForDelivery': 'กำลังจัดส่ง',
      'delivered': 'ส่งแล้ว',
      'cancelled': 'ยกเลิกแล้ว',
      'deliveryUpdatedFor': 'อัปเดตการจัดส่งสำหรับ',
      'deliveryCustomerContact': 'ลูกค้าจัดส่ง',
      'pickupCustomerContact': 'ลูกค้ารับผ้า',
      'saving': 'กำลังบันทึก...',
      'updating': 'กำลังอัปเดต...',
      'todayDeliveryWindow': 'วันนี้ 4 PM - 7 PM',
      'managerOptions': 'สวัสดีผู้จัดการร้าน',
      'managerOptionsDescription': 'วันนี้คุณต้องการทำอะไร?',
      'machineOverview': 'ภาพรวมเครื่อง',
      'inventoryDashboard': 'แดชบอร์ดสินค้าคงคลัง',
      'inventoryDashboardDescription':
          'ติดตามความเสี่ยงของสต็อก การเติมสินค้า และความเคลื่อนไหวของสินค้าได้จากหน้าจอเดียว แล้วเจาะไปยังรายการที่ต้องจัดการ',
      'categories': 'หมวดหมู่',
      'visibleItems': 'รายการที่แสดง',
      'selected': 'ที่เลือก',
      'all': 'ทั้งหมด',
      'lowStock': 'สต็อกต่ำ',
      'outOfStock': 'สินค้าหมด',
      'stockValue': 'มูลค่าสต็อก',
      'pendingPos': 'ใบสั่งซื้อรอดำเนินการ',
      'expiringSoon': 'ใกล้หมดอายุ',
      'categoryOptions': 'ตัวเลือกหมวดหมู่',
      'categoryOptionsDescription':
          'ใช้ทางลัดหมวดหมู่แบบย่อเหล่านี้เป็นตัวกรองสำหรับข้อมูลสินค้าคงคลังทั้งหมด',
      'searchFilterSort': 'ค้นหา กรอง และจัดเรียง',
      'searchByItemOrSku': 'ค้นหาด้วยชื่อสินค้าหรือ SKU',
      'stockStatus': 'สถานะสต็อก',
      'healthy': 'ปกติ',
      'low': 'ต่ำ',
      'sortBy': 'เรียงตาม',
      'sortOrder': 'ลำดับการเรียง',
      'reorderUrgency': 'ความเร่งด่วนในการสั่งซื้อ',
      'quantity': 'จำนวน',
      'lastRestocked': 'เติมสต็อกล่าสุด',
      'descending': 'มากไปน้อย',
      'ascending': 'น้อยไปมาก',
      'reset': 'รีเซ็ต',
      'allInventoryItems': 'สินค้าคงคลังทั้งหมด',
      'inventoryItemsSuffix': 'รายการ',
      'noInventoryItemsMatch': 'ไม่มีสินค้าตรงกับการค้นหาและตัวกรองปัจจุบัน',
      'noExpiry': 'ไม่มีวันหมดอายุ',
      'awaitingApproval': 'รออนุมัติ',
      'restockApproved':
          'คำขอเติมสต็อกได้รับอนุมัติแล้วและกำลังอยู่ในขั้นตอนจัดซื้อ',
      'restockOrder': 'คำสั่งเติมสต็อก',
      'approvedQuantity': 'จำนวนที่อนุมัติ',
      'approvedOn': 'อนุมัติเมื่อ',
      'operatorRemarks': 'หมายเหตุผู้ปฏิบัติงาน',
      'restockPendingApproval':
          'คำขอเติมสต็อกถูกส่งไปยังหน้าจอผู้ปฏิบัติงานและกำลังรอการอนุมัติ',
      'creatingRestockRequest': 'กำลังสร้างคำขอเติมสต็อก...',
      'orderRestock': 'สั่งเติมสต็อก',
      'hideMovementHistory': 'ซ่อนประวัติการเคลื่อนไหว',
      'showMovementHistory': 'แสดงประวัติการเคลื่อนไหว',
      'stockMovementHistory': 'ประวัติการเคลื่อนไหวของสต็อก',
      'stockMovementHistoryDescription':
          'รายการบัญชีช่วยอธิบายได้อย่างชัดเจนว่ายอดคงเหลือปัจจุบันมาถึงจุดนี้ได้อย่างไร',
      'noMovementHistory': 'ยังไม่มีประวัติการเคลื่อนไหวสำหรับรายการนี้',
      'delta': 'การเปลี่ยนแปลง',
      'balance': 'คงเหลือ',
      'when': 'เมื่อไร',
      'reference': 'อ้างอิง',
      'manualEntry': 'บันทึกด้วยตนเอง',
      'by': 'โดย',
      'received': 'รับเข้า',
      'consumed': 'ถูกใช้',
      'transferred': 'โอนย้าย',
      'damaged': 'เสียหาย',
      'returned': 'ส่งคืน',
      'manualCorrection': 'แก้ไขด้วยตนเอง',
      'barcode': 'บาร์โค้ด',
      'packSize': 'ขนาดแพ็ก',
      'unitType': 'ประเภทหน่วย',
      'parLevel': 'ระดับพาร์',
      'sellingPrice': 'ราคาขาย',
      'recordStatus': 'สถานะรายการ',
      'active': 'ใช้งานอยู่',
      'inactive': 'ไม่ใช้งาน',
      'notAssigned': 'ยังไม่ได้กำหนด',
      'notSet': 'ยังไม่ได้ตั้งค่า',
      'notApplicable': 'ไม่เกี่ยวข้อง',
      'urgency': 'ความเร่งด่วน',
      'branchLocationShort': 'สาขา / ตำแหน่ง',
      'detergent': 'ผงซักฟอก',
      'disinfectant': 'น้ำยาฆ่าเชื้อ',
      'liquid': 'ของเหลว',
      'soap': 'สบู่',
      'softener': 'น้ำยาปรับผ้านุ่ม',
    },
    'hi': {
      'appTitle': 'वॉशपॉस',
      'language': 'भाषा',
      'english': 'अंग्रेज़ी',
      'arabic': 'अरबी',
      'thai': 'थाई',
      'hindi': 'हिंदी',
      'loginSubtitle': 'मौजूदा Android डेमो फ्लो के लिए Flutter स्कैफोल्ड।',
      'username': 'यूज़रनेम',
      'pin': 'पिन',
      'loginHint': 'अपने ऑपरेटर क्रेडेंशियल्स का उपयोग करें।',
      'loginFailed':
          'लॉगिन विफल रहा। अपने क्रेडेंशियल्स या बैकएंड कनेक्शन की जांच करें।',
      'login': 'लॉगिन',
      'signingIn': 'लॉगिन हो रहा है...',
      'customerProfileHistory': 'ग्राहक प्रोफ़ाइल और इतिहास',
      'orderHistory': 'ऑर्डर इतिहास',
      'logout': 'लॉग आउट',
      'storeManagerHome': 'स्टोर मैनेजर होम',
      'storeManagerHomeDescription':
          'मशीनों, ग्राहकों, रिपोर्टिंग और दिन के अंत के संचालन सहित स्टोर का हर मुख्य कंट्रोल इस डैशबोर्ड से उपलब्ध है।',
      'available': 'उपलब्ध',
      'running': 'चल रही है',
      'pickup': 'पिकअप',
      'maintenance': 'रखरखाव',
      'restockRequests': 'रीस्टॉक अनुरोध',
      'restockRequestsDescription':
          'इन्वेंटरी से बने रीस्टॉक ऑर्डर यहां ऑपरेटर की स्वीकृति और टिप्पणियों के लिए दिखते हैं, फिर खरीद टीम आगे बढ़ाती है।',
      'pendingApproval': 'स्वीकृति लंबित',
      'requestedQty': 'मांगी गई मात्रा',
      'supplier': 'आपूर्तिकर्ता',
      'branchLocation': 'शाखा / स्थान',
      'requestedBy': 'अनुरोधकर्ता',
      'created': 'बनाया गया',
      'requestNote': 'अनुरोध नोट',
      'approving': 'स्वीकृत किया जा रहा है...',
      'approveWithRemarks': 'टिप्पणियों सहित स्वीकृत करें',
      'inProcurement': 'खरीद प्रक्रिया में',
      'inProcurementDescription':
          'इन इन्वेंटरी अनुरोधों को ऑपरेटर स्क्रीन पर स्वीकृत किया जा चुका है और स्टॉक आने पर खरीद पूरी होने की प्रतीक्षा है।',
      'operatorReady':
          'ऑपरेटर तैयार है। मशीनों, पिकअप, रखरखाव और स्वीकृतियों को इस डैशबोर्ड से ट्रैक करें।',
      'openCustomerScreenError': 'ग्राहक स्क्रीन विंडो नहीं खोली जा सकी।',
      'openWhatsappError':
          'साइकिल पूर्ण होने की सूचना के लिए WhatsApp नहीं खोला जा सका।',
      'unassigned': 'असाइन नहीं किया गया',
      'system': 'सिस्टम',
      'machines': 'मशीनें',
      'inventory': 'इन्वेंटरी',
      'customers': 'ग्राहक',
      'payment': 'भुगतान',
      'orders': 'ऑर्डर',
      'staff': 'स्टाफ',
      'pricing': 'मूल्य निर्धारण',
      'screen': 'स्क्रीन',
      'reports': 'रिपोर्ट',
      'revenue': 'राजस्व',
      'refunds': 'रिफंड',
      'checkout': 'चेकआउट',
      'customerLookup': 'ग्राहक खोज',
      'customerScreenTitle': 'ग्राहक स्क्रीन',
      'operatorPayments': 'ऑपरेटर भुगतान',
      'refundQueue': 'रिफंड कतार',
      'delivery': 'डिलीवरी',
      'pickupDesk': 'पिकअप डेस्क',
      'deliveryDesk': 'डिलीवरी डेस्क',
      'deliveryDeskDescription':
          'ड्राइवर हैंडऑफ शेड्यूल करें, ऑर्डर को डिलीवरी पर भेजें और दरवाज़े पर डिलीवरी की पुष्टि करें।',
      'pickupDeskDescription':
          'रिमाइंडर, कॉल और अंतिम पिकअप पुष्टि के साथ तैयार लोड जल्दी क्लियर करें।',
      'scheduled': 'शेड्यूल्ड',
      'outNow': 'रास्ते में',
      'readyLoads': 'तैयार लोड',
      'statusFilters': 'स्थिति फ़िल्टर',
      'showingTasks': '{count} कार्य दिखाए जा रहे हैं',
      'noTasksForStatus':
          'अभी इस स्थिति फ़िल्टर से मेल खाने वाले कोई डिलीवरी कार्य नहीं हैं।',
      'deliveryTasksEmptyTitle': 'अभी कोई डिलीवरी टास्क नहीं',
      'deliveryTasksEmptyMessage':
          'हाल के भुगतान किए गए ऑर्डर यहां दिखाई देंगे ताकि टीम उन्हें शेड्यूल और पूरा कर सके।',
      'pickupTasksEmptyTitle': 'अभी कोई पिकअप जॉब नहीं',
      'pickupTasksEmptyMessage':
          'जब साइकिल पूरी होगी और मशीन पिकअप-रेडी होगी, तो वह यहां दिखाई देगी।',
      'phone': 'फोन',
      'ref': 'रेफ',
      'amount': 'राशि',
      'machine': 'मशीन',
      'window': 'समय स्लॉट',
      'driver': 'ड्राइवर',
      'callCustomer': 'ग्राहक को कॉल करें',
      'sendReminder': 'रिमाइंडर भेजें',
      'markPickedUp': 'पिकअप पूरा करें',
      'pickupReady': 'पिकअप के लिए तैयार',
      'reminderSent': 'रिमाइंडर भेजा गया',
      'pickedUpStatus': 'पिकअप हो गया',
      'pickupUpdatedFor': 'के लिए पिकअप अपडेट किया गया',
      'cancel': 'रद्द करें',
      'deliveryUpdateSent': 'डिलीवरी अपडेट खोला गया',
      'pickupReminderSent': 'पिकअप रिमाइंडर खोला गया',
      'markedPickedUp': 'को पिकअप किया हुआ चिह्नित किया गया।',
      'scheduleDelivery': 'डिलीवरी शेड्यूल करें',
      'saveDelivery': 'डिलीवरी सेव करें',
      'assignedDriver': 'असाइन किया गया ड्राइवर',
      'deliveryWindow': 'डिलीवरी विंडो',
      'editDelivery': 'डिलीवरी संपादित करें',
      'cancelDelivery': 'डिलीवरी रद्द करें',
      'reopenDelivery': 'डिलीवरी फिर खोलें',
      'sendUpdate': 'अपडेट भेजें',
      'markOutForDelivery': 'आउट फॉर डिलीवरी चिह्नित करें',
      'markDelivered': 'डिलीवर किया हुआ चिह्नित करें',
      'pendingSchedule': 'शेड्यूल लंबित',
      'outForDelivery': 'आउट फॉर डिलीवरी',
      'delivered': 'डिलीवर किया गया',
      'cancelled': 'रद्द किया गया',
      'deliveryUpdatedFor': 'के लिए डिलीवरी अपडेट की गई',
      'deliveryCustomerContact': 'डिलीवरी ग्राहक',
      'pickupCustomerContact': 'पिकअप ग्राहक',
      'saving': 'सेव हो रहा है...',
      'updating': 'अपडेट हो रहा है...',
      'todayDeliveryWindow': 'आज, 4 PM - 7 PM',
      'managerOptions': 'नमस्ते स्टोर मैनेजर',
      'managerOptionsDescription': 'आज आप क्या करना चाहेंगे?',
      'machineOverview': 'मशीन अवलोकन',
      'inventoryDashboard': 'इन्वेंटरी डैशबोर्ड',
      'inventoryDashboardDescription':
          'एक ही स्क्रीन से स्टॉक जोखिम, लंबित रीस्टॉक और आइटम मूवमेंट ट्रैक करें, फिर उन आइटम्स तक जाएं जिन्हें कार्रवाई चाहिए।',
      'categories': 'श्रेणियाँ',
      'visibleItems': 'दिखने वाले आइटम',
      'selected': 'चयनित',
      'all': 'सभी',
      'lowStock': 'कम स्टॉक',
      'outOfStock': 'स्टॉक समाप्त',
      'stockValue': 'स्टॉक मूल्य',
      'pendingPos': 'लंबित पीओ',
      'expiringSoon': 'जल्द समाप्त होने वाले',
      'categoryOptions': 'श्रेणी विकल्प',
      'categoryOptionsDescription':
          'इन कॉम्पैक्ट श्रेणी शॉर्टकट्स को पूरे इन्वेंटरी डेटा पर फ़िल्टर की तरह उपयोग करें।',
      'searchFilterSort': 'खोजें, फ़िल्टर करें और क्रमबद्ध करें',
      'searchByItemOrSku': 'आइटम नाम या SKU से खोजें',
      'stockStatus': 'स्टॉक स्थिति',
      'healthy': 'सामान्य',
      'low': 'कम',
      'sortBy': 'क्रमबद्ध करें',
      'sortOrder': 'क्रम',
      'reorderUrgency': 'रीऑर्डर प्राथमिकता',
      'quantity': 'मात्रा',
      'lastRestocked': 'अंतिम रीस्टॉक',
      'descending': 'घटते क्रम में',
      'ascending': 'बढ़ते क्रम में',
      'reset': 'रीसेट',
      'allInventoryItems': 'सभी इन्वेंटरी आइटम',
      'inventoryItemsSuffix': 'आइटम',
      'noInventoryItemsMatch':
          'मौजूदा खोज और फ़िल्टर से मेल खाने वाले कोई इन्वेंटरी आइटम नहीं हैं।',
      'noExpiry': 'कोई एक्सपायरी नहीं',
      'awaitingApproval': 'स्वीकृति की प्रतीक्षा में',
      'restockApproved':
          'रीस्टॉक अनुरोध स्वीकृत हो चुका है और आइटम अब खरीद प्रक्रिया में है।',
      'restockOrder': 'रीस्टॉक ऑर्डर',
      'approvedQuantity': 'स्वीकृत मात्रा',
      'approvedOn': 'स्वीकृत तिथि',
      'operatorRemarks': 'ऑपरेटर टिप्पणियाँ',
      'restockPendingApproval':
          'रीस्टॉक अनुरोध ऑपरेटर स्क्रीन पर भेज दिया गया है और स्वीकृति की प्रतीक्षा में है।',
      'creatingRestockRequest': 'रीस्टॉक अनुरोध बनाया जा रहा है...',
      'orderRestock': 'ऑर्डर / रीस्टॉक',
      'hideMovementHistory': 'मूवमेंट इतिहास छुपाएं',
      'showMovementHistory': 'मूवमेंट इतिहास दिखाएं',
      'stockMovementHistory': 'स्टॉक मूवमेंट इतिहास',
      'stockMovementHistoryDescription':
          'लेजर एंट्रियाँ बताती हैं कि मौजूदा बैलेंस तक कैसे पहुँचा गया।',
      'noMovementHistory':
          'इस आइटम के लिए अभी कोई मूवमेंट इतिहास दर्ज नहीं है।',
      'delta': 'परिवर्तन',
      'balance': 'बैलेंस',
      'when': 'कब',
      'reference': 'संदर्भ',
      'manualEntry': 'मैनुअल एंट्री',
      'by': 'द्वारा',
      'received': 'प्राप्त',
      'consumed': 'उपयोग किया गया',
      'transferred': 'स्थानांतरित',
      'damaged': 'क्षतिग्रस्त',
      'returned': 'वापस आया',
      'manualCorrection': 'मैनुअल सुधार',
      'barcode': 'बारकोड',
      'packSize': 'पैक साइज़',
      'unitType': 'इकाई प्रकार',
      'parLevel': 'पार लेवल',
      'sellingPrice': 'विक्रय मूल्य',
      'recordStatus': 'रिकॉर्ड स्थिति',
      'active': 'सक्रिय',
      'inactive': 'निष्क्रिय',
      'notAssigned': 'असाइन नहीं',
      'notSet': 'सेट नहीं',
      'notApplicable': 'लागू नहीं',
      'urgency': 'प्राथमिकता',
      'branchLocationShort': 'शाखा / स्थान',
      'detergent': 'डिटर्जेंट',
      'disinfectant': 'डिसइन्फेक्टेंट',
      'liquid': 'लिक्विड',
      'soap': 'साबुन',
      'softener': 'सॉफ्टनर',
    },
  };

  String _text(String key) =>
      _localizedValues[locale.languageCode]?[key] ??
      _localizedValues['en']![key]!;

  String get appTitle => _text('appTitle');
  String get language => _text('language');
  String get english => _text('english');
  String get arabic => _text('arabic');
  String get thai => _text('thai');
  String get hindi => _text('hindi');
  String get loginSubtitle => _text('loginSubtitle');
  String get username => _text('username');
  String get pin => _text('pin');
  String get loginHint => _text('loginHint');
  String get loginFailed => _text('loginFailed');
  String get login => _text('login');
  String get signingIn => _text('signingIn');
  String get customerProfileHistory => _text('customerProfileHistory');
  String get orderHistory => _text('orderHistory');
  String get logout => _text('logout');
  String get storeManagerHome => _text('storeManagerHome');
  String get storeManagerHomeDescription =>
      _text('storeManagerHomeDescription');
  String get available => _text('available');
  String get running => _text('running');
  String get pickup => _text('pickup');
  String get maintenance => _text('maintenance');
  String get restockRequests => _text('restockRequests');
  String get restockRequestsDescription => _text('restockRequestsDescription');
  String get pendingApproval => _text('pendingApproval');
  String get requestedQty => _text('requestedQty');
  String get supplier => _text('supplier');
  String get branchLocation => _text('branchLocation');
  String get requestedBy => _text('requestedBy');
  String get created => _text('created');
  String get requestNote => _text('requestNote');
  String get approving => _text('approving');
  String get approveWithRemarks => _text('approveWithRemarks');
  String get inProcurement => _text('inProcurement');
  String get inProcurementDescription => _text('inProcurementDescription');
  String get operatorReady => _text('operatorReady');
  String get openCustomerScreenError => _text('openCustomerScreenError');
  String get openWhatsappError => _text('openWhatsappError');
  String get unassigned => _text('unassigned');
  String get system => _text('system');
  String get machines => _text('machines');
  String get inventory => _text('inventory');
  String get customers => _text('customers');
  String get payment => _text('payment');
  String get orders => _text('orders');
  String get staff => _text('staff');
  String get pricing => _text('pricing');
  String get screen => _text('screen');
  String get reports => _text('reports');
  String get revenue => _text('revenue');
  String get refunds => _text('refunds');
  String get checkout => _text('checkout');
  String get customerLookup => _text('customerLookup');
  String get customerScreenTitle => _text('customerScreenTitle');
  String get operatorPayments => _text('operatorPayments');
  String get refundQueue => _text('refundQueue');
  String get delivery => _text('delivery');
  String get pickupDesk => _text('pickupDesk');
  String get deliveryDesk => _text('deliveryDesk');
  String get deliveryDeskDescription => _text('deliveryDeskDescription');
  String get pickupDeskDescription => _text('pickupDeskDescription');
  String get scheduled => _text('scheduled');
  String get outNow => _text('outNow');
  String get readyLoads => _text('readyLoads');
  String get statusFilters => _text('statusFilters');
  String showingTasks(int count) =>
      _text('showingTasks').replaceAll('{count}', '$count');
  String get noTasksForStatus => _text('noTasksForStatus');
  String get deliveryTasksEmptyTitle => _text('deliveryTasksEmptyTitle');
  String get deliveryTasksEmptyMessage => _text('deliveryTasksEmptyMessage');
  String get pickupTasksEmptyTitle => _text('pickupTasksEmptyTitle');
  String get pickupTasksEmptyMessage => _text('pickupTasksEmptyMessage');
  String get phone => _text('phone');
  String get ref => _text('ref');
  String get amount => _text('amount');
  String get machine => _text('machine');
  String get window => _text('window');
  String get driver => _text('driver');
  String get callCustomer => _text('callCustomer');
  String get sendReminder => _text('sendReminder');
  String get markPickedUp => _text('markPickedUp');
  String get pickupReady => _text('pickupReady');
  String get reminderSent => _text('reminderSent');
  String get pickedUpStatus => _text('pickedUpStatus');
  String get pickupUpdatedFor => _text('pickupUpdatedFor');
  String get cancel => _text('cancel');
  String get deliveryUpdateSent => _text('deliveryUpdateSent');
  String get pickupReminderSent => _text('pickupReminderSent');
  String get markedPickedUp => _text('markedPickedUp');
  String get scheduleDelivery => _text('scheduleDelivery');
  String get saveDelivery => _text('saveDelivery');
  String get assignedDriver => _text('assignedDriver');
  String get deliveryWindow => _text('deliveryWindow');
  String get editDelivery => _text('editDelivery');
  String get cancelDelivery => _text('cancelDelivery');
  String get reopenDelivery => _text('reopenDelivery');
  String get sendUpdate => _text('sendUpdate');
  String get markOutForDelivery => _text('markOutForDelivery');
  String get markDelivered => _text('markDelivered');
  String get pendingSchedule => _text('pendingSchedule');
  String get outForDelivery => _text('outForDelivery');
  String get delivered => _text('delivered');
  String get cancelled => _text('cancelled');
  String get deliveryUpdatedFor => _text('deliveryUpdatedFor');
  String get deliveryCustomerContact => _text('deliveryCustomerContact');
  String get pickupCustomerContact => _text('pickupCustomerContact');
  String get saving => _text('saving');
  String get updating => _text('updating');
  String get todayDeliveryWindow => _text('todayDeliveryWindow');
  String get managerOptions => _text('managerOptions');
  String get managerOptionsDescription => _text('managerOptionsDescription');
  String get machineOverview => _text('machineOverview');
  String get inventoryDashboard => _text('inventoryDashboard');
  String get inventoryDashboardDescription =>
      _text('inventoryDashboardDescription');
  String get categories => _text('categories');
  String get visibleItems => _text('visibleItems');
  String get selected => _text('selected');
  String get all => _text('all');
  String get lowStock => _text('lowStock');
  String get outOfStock => _text('outOfStock');
  String get stockValue => _text('stockValue');
  String get pendingPos => _text('pendingPos');
  String get expiringSoon => _text('expiringSoon');
  String get categoryOptions => _text('categoryOptions');
  String get categoryOptionsDescription => _text('categoryOptionsDescription');
  String get searchFilterSort => _text('searchFilterSort');
  String get searchByItemOrSku => _text('searchByItemOrSku');
  String get stockStatus => _text('stockStatus');
  String get healthy => _text('healthy');
  String get low => _text('low');
  String get sortBy => _text('sortBy');
  String get sortOrder => _text('sortOrder');
  String get reorderUrgency => _text('reorderUrgency');
  String get quantity => _text('quantity');
  String get lastRestocked => _text('lastRestocked');
  String get descending => _text('descending');
  String get ascending => _text('ascending');
  String get reset => _text('reset');
  String get allInventoryItems => _text('allInventoryItems');
  String get inventoryItemsSuffix => _text('inventoryItemsSuffix');
  String get noInventoryItemsMatch => _text('noInventoryItemsMatch');
  String get noExpiry => _text('noExpiry');
  String get awaitingApproval => _text('awaitingApproval');
  String get restockApproved => _text('restockApproved');
  String get restockOrder => _text('restockOrder');
  String get approvedQuantity => _text('approvedQuantity');
  String get approvedOn => _text('approvedOn');
  String get operatorRemarks => _text('operatorRemarks');
  String get restockPendingApproval => _text('restockPendingApproval');
  String get creatingRestockRequest => _text('creatingRestockRequest');
  String get orderRestock => _text('orderRestock');
  String get hideMovementHistory => _text('hideMovementHistory');
  String get showMovementHistory => _text('showMovementHistory');
  String get stockMovementHistory => _text('stockMovementHistory');
  String get stockMovementHistoryDescription =>
      _text('stockMovementHistoryDescription');
  String get noMovementHistory => _text('noMovementHistory');
  String get delta => _text('delta');
  String get balance => _text('balance');
  String get when => _text('when');
  String get reference => _text('reference');
  String get manualEntry => _text('manualEntry');
  String get by => _text('by');
  String get received => _text('received');
  String get consumed => _text('consumed');
  String get transferred => _text('transferred');
  String get damaged => _text('damaged');
  String get returned => _text('returned');
  String get manualCorrection => _text('manualCorrection');
  String get barcode => _text('barcode');
  String get packSize => _text('packSize');
  String get unitType => _text('unitType');
  String get parLevel => _text('parLevel');
  String get sellingPrice => _text('sellingPrice');
  String get recordStatus => _text('recordStatus');
  String get active => _text('active');
  String get inactive => _text('inactive');
  String get notAssigned => _text('notAssigned');
  String get notSet => _text('notSet');
  String get notApplicable => _text('notApplicable');
  String get urgency => _text('urgency');
  String get branchLocationShort => _text('branchLocationShort');

  String languageName(String code) {
    switch (code) {
      case 'ar':
        return arabic;
      case 'th':
        return thai;
      case 'hi':
        return hindi;
      default:
        return english;
    }
  }

  String managerActionShortTitle(String title) {
    switch (title) {
      case 'Machines':
        return _text('machines');
      case 'Inventory':
        return _text('inventory');
      case 'Customer Lookup':
        return _text('customers');
      case 'Payment':
        return _text('payment');
      case 'Orders':
        return _text('orders');
      case 'Staff':
        return _text('staff');
      case 'Pricing':
        return _text('pricing');
      case 'Customer Screen':
        return _text('screen');
      case 'Delivery':
        return _text('delivery');
      case 'Pickup Desk':
        return _text('pickup');
      case 'Reports':
        return _text('reports');
      case 'Maintenance':
        return _text('maintenance');
      case 'Revenue & Day End':
        return _text('revenue');
      case 'Complaint Refund':
        return _text('refunds');
      default:
        return title;
    }
  }

  String inventoryItemsTitle(String? category) {
    if (category == null || category.isEmpty) {
      return allInventoryItems;
    }
    return '${inventoryCategoryName(category)} $inventoryItemsSuffix';
  }

  String inventoryCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'detergent':
        return _text('detergent');
      case 'disinfectant':
        return _text('disinfectant');
      case 'liquid':
        return _text('liquid');
      case 'soap':
        return _text('soap');
      case 'softener':
        return _text('softener');
      default:
        return category;
    }
  }

  String inventoryStockStatusLabel(String status) {
    switch (status) {
      case 'inProcurement':
        return inProcurement;
      case 'outOfStock':
        return outOfStock;
      case 'low':
        return low;
      default:
        return healthy;
    }
  }

  String inventoryMovementLabel(String movementType) {
    switch (movementType) {
      case 'received':
        return received;
      case 'consumed':
        return consumed;
      case 'transferred':
        return transferred;
      case 'damaged':
        return damaged;
      case 'returned':
        return returned;
      case 'manualCorrection':
        return manualCorrection;
      default:
        return movementType;
    }
  }

  TextDirection get estimatedDirection =>
      _isArabic ? TextDirection.rtl : TextDirection.ltr;
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsBuildContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
