import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ManagerOptionIconType {
  machines,
  inventory,
  customerLookup,
  payment,
  orders,
  staff,
  pricing,
  customerScreen,
  reports,
  maintenance,
  revenue,
  complaintRefund,
}

class ManagerOptionIcon extends StatelessWidget {
  const ManagerOptionIcon({
    super.key,
    required this.type,
    this.size = 86,
  });

  final ManagerOptionIconType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svgByType(type),
      width: size,
      height: size,
    );
  }
}

String _svgByType(ManagerOptionIconType type) {
  return switch (type) {
    ManagerOptionIconType.machines => _machinesSvg,
    ManagerOptionIconType.inventory => _inventorySvg,
    ManagerOptionIconType.customerLookup => _customerLookupSvg,
    ManagerOptionIconType.payment => _paymentSvg,
    ManagerOptionIconType.orders => _ordersSvg,
    ManagerOptionIconType.staff => _staffSvg,
    ManagerOptionIconType.pricing => _pricingSvg,
    ManagerOptionIconType.customerScreen => _customerScreenSvg,
    ManagerOptionIconType.reports => _reportsSvg,
    ManagerOptionIconType.maintenance => _maintenanceSvg,
    ManagerOptionIconType.revenue => _revenueSvg,
    ManagerOptionIconType.complaintRefund => _complaintRefundSvg,
  };
}

const _machinesSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="16" y1="12" x2="112" y2="116" gradientUnits="userSpaceOnUse">
      <stop stop-color="#DBF5FF"/>
      <stop offset="1" stop-color="#CBE6FF"/>
    </linearGradient>
    <linearGradient id="metal" x1="34" y1="24" x2="94" y2="102" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#D6DEE8"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <rect x="26" y="22" width="76" height="84" rx="18" fill="url(#metal)" stroke="#68859A" stroke-width="2.5"/>
  <rect x="34" y="30" width="18" height="8" rx="4" fill="#7AA7C7"/>
  <circle cx="64" cy="67" r="24" fill="#24435D"/>
  <circle cx="64" cy="67" r="18" fill="#7ED2FF"/>
  <path d="M51 69c4-11 18-15 28-9-2 11-12 20-24 19-4-3-6-6-4-10Z" fill="#DDF7FF"/>
  <circle cx="82" cy="34" r="5" fill="#4FC16D"/>
</svg>
''';

const _inventorySvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="15" y1="15" x2="111" y2="113" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF4D7"/>
      <stop offset="1" stop-color="#FFE0A1"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <rect x="28" y="28" width="72" height="24" rx="8" fill="#9D6B3B"/>
  <rect x="28" y="56" width="72" height="18" rx="6" fill="#B77E45"/>
  <rect x="28" y="78" width="32" height="22" rx="6" fill="#D59B5A"/>
  <rect x="64" y="78" width="36" height="22" rx="6" fill="#8FC1F0"/>
  <path d="M41 39h18" stroke="#FFF4D7" stroke-width="4" stroke-linecap="round"/>
  <path d="M70 66h18" stroke="#FFF4D7" stroke-width="4" stroke-linecap="round"/>
  <path d="M74 89h16" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>
</svg>
''';

const _customerLookupSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="18" y1="14" x2="112" y2="114" gradientUnits="userSpaceOnUse">
      <stop stop-color="#E8F7E8"/>
      <stop offset="1" stop-color="#C7EFD0"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <circle cx="51" cy="48" r="16" fill="#F0B594"/>
  <path d="M31 84c4-15 16-24 30-24s27 9 30 24" fill="#3A7CA5"/>
  <circle cx="84" cy="86" r="18" fill="#FFFFFF" stroke="#4B6C83" stroke-width="3"/>
  <path d="M97 99l11 11" stroke="#4B6C83" stroke-width="5" stroke-linecap="round"/>
  <circle cx="84" cy="86" r="7" fill="#8FC1F0"/>
</svg>
''';

const _paymentSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="14" y1="16" x2="114" y2="112" gradientUnits="userSpaceOnUse">
      <stop stop-color="#E3F0FF"/>
      <stop offset="1" stop-color="#B7D7FF"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <rect x="24" y="32" width="80" height="52" rx="14" fill="#1F5E94"/>
  <rect x="24" y="44" width="80" height="10" fill="#163F61"/>
  <rect x="34" y="62" width="20" height="8" rx="4" fill="#9CC9F2"/>
  <path d="M76 89v-9" stroke="#2A8F53" stroke-width="8" stroke-linecap="round"/>
  <path d="M66 99h20" stroke="#2A8F53" stroke-width="8" stroke-linecap="round"/>
  <circle cx="76" cy="94" r="19" fill="none" stroke="#2A8F53" stroke-width="6"/>
</svg>
''';

const _ordersSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="18" y1="12" x2="108" y2="116" gradientUnits="userSpaceOnUse">
      <stop stop-color="#F5EAFE"/>
      <stop offset="1" stop-color="#DFC8FB"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <rect x="34" y="22" width="60" height="84" rx="10" fill="#FFFFFF" stroke="#8563A5" stroke-width="3"/>
  <rect x="46" y="18" width="36" height="12" rx="6" fill="#8563A5"/>
  <path d="M45 48h38M45 62h38M45 76h24" stroke="#A180C2" stroke-width="5" stroke-linecap="round"/>
  <path d="M73 80l7 7 13-15" fill="none" stroke="#42A66E" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _staffSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="18" y1="18" x2="110" y2="110" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF1E6"/>
      <stop offset="1" stop-color="#FFD5B8"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <circle cx="48" cy="46" r="14" fill="#E8A27A"/>
  <circle cx="82" cy="50" r="12" fill="#F1B692"/>
  <path d="M30 87c4-13 12-21 24-21s20 8 24 21" fill="#2E6D9C"/>
  <path d="M63 89c3-10 10-16 19-16 9 0 16 6 19 16" fill="#6B8BA4"/>
</svg>
''';

const _pricingSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="12" y1="14" x2="112" y2="116" gradientUnits="userSpaceOnUse">
      <stop stop-color="#EAFBF5"/>
      <stop offset="1" stop-color="#C8F0DE"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <path d="M34 35h40l20 20v38H34z" fill="#FFFFFF" stroke="#5E9879" stroke-width="3" stroke-linejoin="round"/>
  <path d="M74 35v20h20" fill="#D9F3E5"/>
  <circle cx="53" cy="77" r="10" fill="#2F8F61"/>
  <path d="M50 72h6a3 3 0 1 1 0 6h-6a3 3 0 1 0 0 6h6" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/>
</svg>
''';

const _customerScreenSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="13" y1="16" x2="114" y2="111" gradientUnits="userSpaceOnUse">
      <stop stop-color="#EAF2FF"/>
      <stop offset="1" stop-color="#C6DAFF"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <rect x="24" y="28" width="80" height="52" rx="10" fill="#17395C"/>
  <rect x="31" y="35" width="66" height="38" rx="7" fill="#8CCFFF"/>
  <path d="M52 94h24" stroke="#355C7D" stroke-width="7" stroke-linecap="round"/>
  <path d="M64 80v14" stroke="#355C7D" stroke-width="7" stroke-linecap="round"/>
  <path d="M86 47h10m-5-5v10" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>
</svg>
''';

const _reportsSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="15" y1="12" x2="114" y2="114" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF5E8"/>
      <stop offset="1" stop-color="#FFE1B7"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <rect x="28" y="30" width="72" height="68" rx="12" fill="#FFFFFF" stroke="#AE7A3E" stroke-width="3"/>
  <path d="M43 83V61M64 83V49M85 83V39" stroke="#D28C3D" stroke-width="8" stroke-linecap="round"/>
  <path d="M40 47c9 5 17 2 24-7 5-6 11-9 22-10" fill="none" stroke="#4F88C6" stroke-width="4" stroke-linecap="round"/>
</svg>
''';

const _maintenanceSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="14" y1="12" x2="114" y2="114" gradientUnits="userSpaceOnUse">
      <stop stop-color="#F1F4F8"/>
      <stop offset="1" stop-color="#D9E2EC"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <circle cx="48" cy="74" r="18" fill="#5B7083"/>
  <circle cx="48" cy="74" r="8" fill="#E9EEF3"/>
  <path d="M48 48l7 8 12-3 5 11 12 5-3 12 8 7-9 9-7-8-12 3-5-11-12-5 3-12-8-7 9-9Z" fill="#7C92A7"/>
  <path d="M71 32l25 25" stroke="#F2A03D" stroke-width="8" stroke-linecap="round"/>
  <path d="M91 28l9 9-10 10-9-9Z" fill="#F8C36E"/>
</svg>
''';

const _revenueSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="14" y1="12" x2="114" y2="114" gradientUnits="userSpaceOnUse">
      <stop stop-color="#E8FFF4"/>
      <stop offset="1" stop-color="#BFF2D4"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <path d="M30 86h68" stroke="#396C55" stroke-width="6" stroke-linecap="round"/>
  <path d="M38 80V61M58 80V49M78 80V39M98 80V29" stroke="#2E9C69" stroke-width="10" stroke-linecap="round"/>
  <path d="M35 50l19-7 17 8 24-19" fill="none" stroke="#4E7FC4" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M91 31h9v9" fill="none" stroke="#4E7FC4" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _complaintRefundSvg = '''
<svg viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="14" y1="16" x2="114" y2="112" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF0F0"/>
      <stop offset="1" stop-color="#FFD0D0"/>
    </linearGradient>
  </defs>
  <rect x="10" y="10" width="108" height="108" rx="28" fill="url(#bg)"/>
  <path d="M64 32c-17 0-31 11-31 26 0 8 4 14 11 19l-2 17 15-9c2 0 5 1 7 1 17 0 31-11 31-28S81 32 64 32Z" fill="#FFFFFF" stroke="#B56A6A" stroke-width="3"/>
  <path d="M64 48v15" stroke="#C14D4D" stroke-width="6" stroke-linecap="round"/>
  <circle cx="64" cy="71" r="4" fill="#C14D4D"/>
  <path d="M77 95c0 8-6 14-14 14s-14-6-14-14 6-14 14-14" fill="none" stroke="#3A8F61" stroke-width="6" stroke-linecap="round"/>
  <path d="M81 90l-4 5-5-4" fill="none" stroke="#3A8F61" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';
